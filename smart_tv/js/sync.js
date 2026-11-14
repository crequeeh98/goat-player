// GOATPlayer Smart TV - Supabase Remote Sync Engine
(function() {
  var SUPABASE_URL = 'https://ejxepyztbcxcuxbgjwsh.supabase.co';
  var SUPABASE_ANON_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVqeGVweXp0YmN4Y3V4Ymdqd3NoIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODg1MzcwNTcsImV4cCI6MjEwNDExMzA1N30.DGTV-_uwmmo4CN7CBZuqR1rqkh121GF2BqgNEvGj2LA';
  var PORTAL_URL = 'https://goat-player.vercel.app';
  var DEVICE_ID_KEY = 'goat_tv_device_id';

  var _pollTimer = null;
  var _processedActionIds = {};
  var _currentSessionPin = null;

  function decryptSyncAction(syncAction, pin, deviceId) {
    if (!syncAction || !syncAction.encrypted || !syncAction.data || !syncAction.iv || !pin) {
      return Promise.resolve(syncAction);
    }
    if (!window.crypto || !window.crypto.subtle) {
      console.warn('[TVSync] WebCrypto unavailable for zero-knowledge decryption');
      return Promise.resolve(syncAction);
    }
    try {
      var enc = new TextEncoder();
      return window.crypto.subtle.importKey(
        'raw',
        enc.encode(pin.trim()),
        { name: 'PBKDF2' },
        false,
        ['deriveKey']
      ).then(function(pinKey) {
        return window.crypto.subtle.deriveKey(
          {
            name: 'PBKDF2',
            salt: enc.encode('GOATPlayer_Pairing_Salt_' + deviceId.trim().toUpperCase()),
            iterations: 10000,
            hash: 'SHA-256'
          },
          pinKey,
          { name: 'AES-GCM', length: 256 },
          false,
          ['decrypt']
        );
      }).then(function(aesKey) {
        function fromHex(hex) {
          var bytes = new Uint8Array(hex.length / 2);
          for (var i = 0; i < hex.length; i += 2) {
            bytes[i / 2] = parseInt(hex.substr(i, 2), 16);
          }
          return bytes;
        }

        var ivBytes = fromHex(syncAction.iv);
        var cipherBytes = fromHex(syncAction.data);

        return window.crypto.subtle.decrypt(
          { name: 'AES-GCM', iv: ivBytes },
          aesKey,
          cipherBytes
        );
      }).then(function(plainBuffer) {
        var plainStr = new TextDecoder().decode(plainBuffer);
        return JSON.parse(plainStr);
      }).catch(function(err) {
        console.error('[TVSync] Decryption error:', err);
        return syncAction;
      });
    } catch (e) {
      console.error('[TVSync] Decryption setup error:', e);
      return Promise.resolve(syncAction);
    }
  }

  function getDeviceId() {
    var id = localStorage.getItem(DEVICE_ID_KEY);
    if (!id || !id.startsWith('GP-')) {
      var chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
      var part1 = String(Math.floor(1000 + Math.random() * 9000));
      var part2 = '';
      for (var i = 0; i < 4; i++) {
        part2 += chars.charAt(Math.floor(Math.random() * chars.length));
      }
      id = 'GP-' + part1 + '-' + part2;
      localStorage.setItem(DEVICE_ID_KEY, id);
    }
    return id;
  }

  function generatePin() {
    return String(Math.floor(100000 + Math.random() * 900000));
  }

  function getLocalPlaylists() {
    if (!window.TVStorage) return [];
    var accounts = window.TVStorage.getAccounts();
    return accounts.map(function(acc) {
      var hasCreds = !!(acc.username && acc.username.trim().length > 0);
      var isExplicitM3uUrl = !!(acc.serverUrl && (acc.serverUrl.indexOf('.m3u') !== -1 || acc.serverUrl.indexOf('.m3u8') !== -1));
      var isM3u = isExplicitM3uUrl || (!hasCreds && acc.type === 'm3u');
      return {
        id: acc.id,
        playlist_name: acc.name || 'IPTV Playlist',
        type: isM3u ? 'm3u' : 'xtream',
        sync_live_tv: acc.syncLiveTv !== false,
        sync_movies: acc.syncMovies !== false,
        sync_series: acc.syncSeries !== false
      };
    });
  }

  function startPairingSession() {
    var deviceId = getDeviceId();
    var pin = generatePin();
    _currentSessionPin = pin;
    var expiresAt = new Date(Date.now() + 20 * 60 * 1000);
    var qrUrl = PORTAL_URL + '?device=' + encodeURIComponent(deviceId) + '&pin=' + encodeURIComponent(pin);

    var payload = {
      device_id: deviceId,
      pin: pin,
      pin_expires_at: expiresAt.toISOString(),
      status: 'pending',
      playlists: getLocalPlaylists(),
      sync_action: null,
      updated_at: new Date().toISOString()
    };

    return fetch(SUPABASE_URL + '/rest/v1/remote_devices', {
      method: 'POST',
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': 'Bearer ' + SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
        'Prefer': 'resolution=merge-duplicates'
      },
      body: JSON.stringify(payload)
    })
    .then(function(res) {
      if (!res.ok) throw new Error('Supabase response error: HTTP ' + res.status);
      return {
        deviceId: deviceId,
        pin: pin,
        expiresAt: expiresAt,
        qrUrl: qrUrl
      };
    });
  }

  function closePairingSession(deviceId) {
    _currentSessionPin = null;
    if (!deviceId) return Promise.resolve();
    stopPolling();
    return fetch(SUPABASE_URL + '/rest/v1/remote_devices?device_id=eq.' + encodeURIComponent(deviceId), {
      method: 'PATCH',
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': 'Bearer ' + SUPABASE_ANON_KEY,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        status: 'disconnected',
        pin_expires_at: new Date().toISOString(),
        sync_action: null,
        updated_at: new Date().toISOString()
      })
    }).catch(function(err) {
      console.warn('Could not close remote session in Supabase:', err);
    });
  }

  function patchDeviceSyncState(deviceId, payload) {
    deviceId = deviceId || getDeviceId();
    return fetch(SUPABASE_URL + '/rest/v1/remote_devices?device_id=eq.' + encodeURIComponent(deviceId), {
      method: 'PATCH',
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': 'Bearer ' + SUPABASE_ANON_KEY,
        'Content-Type': 'application/json'
      },
      body: JSON.stringify(payload)
    }).catch(function() {});
  }

  function acknowledgeSync(deviceId) {
    return patchDeviceSyncState(deviceId, {
      sync_action: null,
      status: 'connected',
      playlists: getLocalPlaylists(),
      updated_at: new Date().toISOString()
    });
  }

  function reportSyncError(deviceId, actionId, errorMessage) {
    return patchDeviceSyncState(deviceId, {
      sync_action: {
        action: 'error',
        action_id: actionId || ('err_' + Date.now()),
        error_message: errorMessage || 'Connection failed',
        timestamp: new Date().toISOString()
      },
      status: 'connected',
      updated_at: new Date().toISOString()
    });
  }

  function pushPlaylists(deviceId) {
    deviceId = deviceId || getDeviceId();
    return fetch(SUPABASE_URL + '/rest/v1/remote_devices?device_id=eq.' + encodeURIComponent(deviceId), {
      method: 'PATCH',
      headers: {
        'apikey': SUPABASE_ANON_KEY,
        'Authorization': 'Bearer ' + SUPABASE_ANON_KEY,
        'Content-Type': 'application/json',
        'Prefer': 'return=minimal'
      },
      body: JSON.stringify({
        playlists: getLocalPlaylists(),
        updated_at: new Date().toISOString()
      })
    }).catch(function(err) {
      console.warn('Could not push playlists to Supabase:', err);
    });
  }

  function startPolling(deviceId, onEvent) {
    stopPolling();

    _pollTimer = setInterval(function() {
      fetch(SUPABASE_URL + '/rest/v1/remote_devices?device_id=eq.' + encodeURIComponent(deviceId) + '&select=*', {
        method: 'GET',
        headers: {
          'apikey': SUPABASE_ANON_KEY,
          'Authorization': 'Bearer ' + SUPABASE_ANON_KEY
        }
      })
      .then(function(res) {
        if (!res.ok) return null;
        return res.json();
      })
      .then(function(rows) {
        if (!rows || rows.length === 0) return;
        var record = rows[0];

        // 1. Check sync_action (structured action from web portal)
        if (record.sync_action && typeof record.sync_action === 'object') {
          var rawAction = record.sync_action;
          var decryptPromise = (rawAction.encrypted === true && _currentSessionPin)
            ? decryptSyncAction(rawAction, _currentSessionPin, deviceId)
            : Promise.resolve(rawAction);

          decryptPromise.then(function(actionObj) {
            if (!actionObj || typeof actionObj !== 'object') return;
            var actionType = actionObj.action;
            if (actionType === 'error') return;
            var actionId = actionObj.action_id || (actionType + '_' + (actionObj.timestamp || Date.now()));

            if (_processedActionIds[actionId]) return;
            _processedActionIds[actionId] = true;

            var deferredAck = false;
            var ackFn = function(errMessage) {
              if (errMessage) {
                return reportSyncError(deviceId, actionId, errMessage);
              }
              return acknowledgeSync(deviceId);
            };

            // Perform local action FIRST so getLocalPlaylists() is updated before acknowledging
          if (actionType === 'add') {
            if (onEvent) {
              deferredAck = true;
              var isM3u = actionObj.type === 'm3u' || (!actionObj.username && !actionObj.password) || (actionObj.server_url && (actionObj.server_url.indexOf('.m3u') !== -1 || actionObj.server_url.indexOf('.m3u8') !== -1));
              onEvent({
                type: 'accountAdded',
                ack: ackFn,
                account: {
                  id: actionObj.id || undefined,
                  type: isM3u ? 'm3u' : undefined,
                  serverUrl: actionObj.server_url || '',
                  username: actionObj.username || '',
                  password: actionObj.password || '',
                  name: actionObj.playlist_name || actionObj.username || (isM3u ? 'M3U Playlist' : 'Remote Playlist'),
                  syncLiveTv: actionObj.sync_live_tv !== undefined ? !!actionObj.sync_live_tv : (actionObj.syncLiveTv !== undefined ? !!actionObj.syncLiveTv : true),
                  syncMovies: actionObj.sync_movies !== undefined ? !!actionObj.sync_movies : (actionObj.syncMovies !== undefined ? !!actionObj.syncMovies : true),
                  syncSeries: actionObj.sync_series !== undefined ? !!actionObj.sync_series : (actionObj.syncSeries !== undefined ? !!actionObj.syncSeries : true)
                }
              });
            }
          } else if (actionType === 'edit') {
            if (window.TVStorage) {
              var accs = window.TVStorage.getAccounts();
              var targetAcc = accs.find(function(a) {
                if (actionObj.id && String(a.id) === String(actionObj.id)) return true;
                var oldServer = (actionObj.old_server_url || actionObj.server_url || '').trim().toLowerCase().replace(/\/+$/, '');
                var oldUser = (actionObj.old_username || actionObj.username || '').trim().toLowerCase();
                var sA = (a.serverUrl || '').trim().toLowerCase().replace(/\/+$/, '');
                return sA === oldServer && (a.username || '').trim().toLowerCase() === oldUser;
              });

              var updatedAcc = null;
              var credentialsChanged = false;
              if (targetAcc) {
                var newServerUrl = (actionObj.server_url && actionObj.server_url.trim().length > 0) ? actionObj.server_url.trim() : targetAcc.serverUrl;
                var newUsername = (actionObj.username && actionObj.username.trim().length > 0) ? actionObj.username.trim() : (targetAcc.username || '');
                var newPassword = (actionObj.password && actionObj.password.trim().length > 0) ? actionObj.password.trim() : (targetAcc.password || '');
                var newName = (actionObj.playlist_name && actionObj.playlist_name.trim().length > 0) ? actionObj.playlist_name.trim() : (targetAcc.name || targetAcc.username);

                credentialsChanged = (newServerUrl !== targetAcc.serverUrl) ||
                  (newUsername !== (targetAcc.username || '')) ||
                  (newPassword !== (targetAcc.password || ''));

                var isM3u = false;
                if (actionObj.type === 'm3u') {
                  isM3u = true;
                } else if (actionObj.type === 'xtream') {
                  isM3u = false;
                } else if (newServerUrl && (newServerUrl.indexOf('.m3u') !== -1 || newServerUrl.indexOf('.m3u8') !== -1)) {
                  isM3u = true;
                } else if (newUsername && newPassword) {
                  isM3u = false;
                } else if (targetAcc.type === 'm3u') {
                  isM3u = true;
                }

                var syncLiveTv = actionObj.sync_live_tv !== undefined ? !!actionObj.sync_live_tv : (actionObj.syncLiveTv !== undefined ? !!actionObj.syncLiveTv : (targetAcc.syncLiveTv !== false));
                var syncMovies = actionObj.sync_movies !== undefined ? !!actionObj.sync_movies : (actionObj.syncMovies !== undefined ? !!actionObj.syncMovies : (targetAcc.syncMovies !== false));
                var syncSeries = actionObj.sync_series !== undefined ? !!actionObj.sync_series : (actionObj.syncSeries !== undefined ? !!actionObj.syncSeries : (targetAcc.syncSeries !== false));

                updatedAcc = Object.assign({}, targetAcc, {
                  type: isM3u ? 'm3u' : undefined,
                  serverUrl: newServerUrl,
                  username: newUsername,
                  password: newPassword,
                  name: newName,
                  syncLiveTv: syncLiveTv,
                  syncMovies: syncMovies,
                  syncSeries: syncSeries
                });
                if (!credentialsChanged) {
                  window.TVStorage.saveAccount(updatedAcc);
                }
              } else if (actionObj.id) {
                credentialsChanged = true;
                var isM3uNew = actionObj.type === 'm3u' || (!actionObj.username && !actionObj.password) || (actionObj.server_url && (actionObj.server_url.indexOf('.m3u') !== -1 || actionObj.server_url.indexOf('.m3u8') !== -1));
                updatedAcc = {
                  id: actionObj.id,
                  type: isM3uNew ? 'm3u' : undefined,
                  serverUrl: actionObj.server_url || '',
                  username: actionObj.username || '',
                  password: actionObj.password || '',
                  name: actionObj.playlist_name || actionObj.username || (isM3uNew ? 'M3U Playlist' : 'Remote Playlist'),
                  syncLiveTv: actionObj.sync_live_tv !== undefined ? !!actionObj.sync_live_tv : (actionObj.syncLiveTv !== undefined ? !!actionObj.syncLiveTv : true),
                  syncMovies: actionObj.sync_movies !== undefined ? !!actionObj.sync_movies : (actionObj.syncMovies !== undefined ? !!actionObj.syncMovies : true),
                  syncSeries: actionObj.sync_series !== undefined ? !!actionObj.sync_series : (actionObj.syncSeries !== undefined ? !!actionObj.syncSeries : true)
                };
              }
              if (onEvent) {
                if (targetAcc && !credentialsChanged) {
                  onEvent({ type: 'accountUpdated', account: updatedAcc, credentialsChanged: false });
                } else if (updatedAcc) {
                  deferredAck = true;
                  onEvent({ type: 'accountUpdated', account: updatedAcc, targetAcc: targetAcc, credentialsChanged: true, isNew: !targetAcc, ack: ackFn });
                }
              }
            }
          } else if (actionType === 'delete') {
            if (window.TVStorage) {
              var accs = window.TVStorage.getAccounts();
              var targetAcc = accs.find(function(a) {
                if (actionObj.id && String(a.id) === String(actionObj.id)) return true;
                if (actionObj.server_url) {
                  var sA = (a.serverUrl || '').trim().toLowerCase().replace(/\/+$/, '');
                  var sB = (actionObj.server_url || '').trim().toLowerCase().replace(/\/+$/, '');
                  return sA === sB && (a.username || '').trim().toLowerCase() === (actionObj.username || '').trim().toLowerCase();
                }
                return false;
              });

              var delId = targetAcc ? targetAcc.id : actionObj.id;
              if (delId) {
                window.TVStorage.deleteAccount(delId);
              }
              if (onEvent) onEvent({ type: 'accountDeleted', id: delId });
            }
          }

          if (!deferredAck) {
            acknowledgeSync(deviceId);
          }
          }); // end decryptPromise.then
        }
        // 2. Fallback: legacy status === 'linked' with flat credentials
        else if (record.status === 'linked' && record.server_url) {
          var legacyKey = (record.server_url || '') + '::' + (record.username || '');
          if (_processedActionIds[legacyKey]) return;
          _processedActionIds[legacyKey] = true;

          if (onEvent) {
            onEvent({
              type: 'accountAdded',
              account: {
                serverUrl: record.server_url || '',
                username: record.username || '',
                password: record.password || '',
                name: record.playlist_name || record.username || 'Remote Playlist'
              }
            });
          }

          fetch(SUPABASE_URL + '/rest/v1/remote_devices?device_id=eq.' + encodeURIComponent(deviceId), {
            method: 'PATCH',
            headers: {
              'apikey': SUPABASE_ANON_KEY,
              'Authorization': 'Bearer ' + SUPABASE_ANON_KEY,
              'Content-Type': 'application/json'
            },
            body: JSON.stringify({
              status: 'connected',
              playlists: getLocalPlaylists(),
              updated_at: new Date().toISOString()
            })
          }).catch(function() {});
        }
      })
      .catch(function(err) {
        console.warn('Sync polling check error:', err);
      });
    }, 2500);
  }

  function stopPolling() {
    if (_pollTimer) {
      clearInterval(_pollTimer);
      _pollTimer = null;
    }
  }

  window.TVSync = {
    getDeviceId: getDeviceId,
    getLocalPlaylists: getLocalPlaylists,
    pushPlaylists: pushPlaylists,
    startPairingSession: startPairingSession,
    closePairingSession: closePairingSession,
    startPolling: startPolling,
    stopPolling: stopPolling
  };
})();
