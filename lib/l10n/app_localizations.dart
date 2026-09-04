import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'GOATPlayer'**
  String get appTitle;

  /// No description provided for @liveTv.
  ///
  /// In en, this message translates to:
  /// **'Live TV'**
  String get liveTv;

  /// No description provided for @movies.
  ///
  /// In en, this message translates to:
  /// **'Movies'**
  String get movies;

  /// No description provided for @series.
  ///
  /// In en, this message translates to:
  /// **'Series'**
  String get series;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @vpnStatus.
  ///
  /// In en, this message translates to:
  /// **'VPN Status'**
  String get vpnStatus;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @accounts.
  ///
  /// In en, this message translates to:
  /// **'Accounts'**
  String get accounts;

  /// No description provided for @addAccount.
  ///
  /// In en, this message translates to:
  /// **'Add Account'**
  String get addAccount;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @serverUrl.
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get serverUrl;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @expires.
  ///
  /// In en, this message translates to:
  /// **'Expires'**
  String get expires;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @allCategories.
  ///
  /// In en, this message translates to:
  /// **'All Categories'**
  String get allCategories;

  /// No description provided for @typeToSearch.
  ///
  /// In en, this message translates to:
  /// **'Type to search across entire catalog.'**
  String get typeToSearch;

  /// No description provided for @noResultsFound.
  ///
  /// In en, this message translates to:
  /// **'No results found.'**
  String get noResultsFound;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error: '**
  String get error;

  /// No description provided for @selectCategory.
  ///
  /// In en, this message translates to:
  /// **'Select a category'**
  String get selectCategory;

  /// No description provided for @selectChannel.
  ///
  /// In en, this message translates to:
  /// **'Select a channel'**
  String get selectChannel;

  /// No description provided for @noCategories.
  ///
  /// In en, this message translates to:
  /// **'No categories'**
  String get noCategories;

  /// No description provided for @selectChannelEpg.
  ///
  /// In en, this message translates to:
  /// **'Select a channel to view EPG'**
  String get selectChannelEpg;

  /// No description provided for @failedToLoadEpg.
  ///
  /// In en, this message translates to:
  /// **'Failed to load EPG: '**
  String get failedToLoadEpg;

  /// No description provided for @noUpcomingEpg.
  ///
  /// In en, this message translates to:
  /// **'No upcoming EPG data available'**
  String get noUpcomingEpg;

  /// No description provided for @importWireguard.
  ///
  /// In en, this message translates to:
  /// **'Import Wireguard VPN'**
  String get importWireguard;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @defaultAdded.
  ///
  /// In en, this message translates to:
  /// **'Default / Added'**
  String get defaultAdded;

  /// No description provided for @aToZ.
  ///
  /// In en, this message translates to:
  /// **'A - Z'**
  String get aToZ;

  /// No description provided for @zToA.
  ///
  /// In en, this message translates to:
  /// **'Z - A'**
  String get zToA;

  /// No description provided for @selectCategoryOrSearch.
  ///
  /// In en, this message translates to:
  /// **'Select a category or search globally'**
  String get selectCategoryOrSearch;

  /// No description provided for @noMoviesFound.
  ///
  /// In en, this message translates to:
  /// **'No movies found.'**
  String get noMoviesFound;

  /// No description provided for @noCategoriesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No categories available'**
  String get noCategoriesAvailable;

  /// No description provided for @playMovie.
  ///
  /// In en, this message translates to:
  /// **'Play Movie'**
  String get playMovie;

  /// No description provided for @selectAudioTrack.
  ///
  /// In en, this message translates to:
  /// **'Select Audio Track'**
  String get selectAudioTrack;

  /// No description provided for @selectSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Select Subtitle'**
  String get selectSubtitle;

  /// No description provided for @season.
  ///
  /// In en, this message translates to:
  /// **'Season '**
  String get season;

  /// No description provided for @noSeriesFound.
  ///
  /// In en, this message translates to:
  /// **'No series found.'**
  String get noSeriesFound;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @german.
  ///
  /// In en, this message translates to:
  /// **'Deutsch'**
  String get german;

  /// No description provided for @epgSchedule.
  ///
  /// In en, this message translates to:
  /// **'EPG Schedule'**
  String get epgSchedule;

  /// No description provided for @director.
  ///
  /// In en, this message translates to:
  /// **'Director'**
  String get director;

  /// No description provided for @cast.
  ///
  /// In en, this message translates to:
  /// **'Cast'**
  String get cast;

  /// No description provided for @searchMovies.
  ///
  /// In en, this message translates to:
  /// **'Search movies...'**
  String get searchMovies;

  /// No description provided for @searchSeries.
  ///
  /// In en, this message translates to:
  /// **'Search series...'**
  String get searchSeries;

  /// No description provided for @masterSearch.
  ///
  /// In en, this message translates to:
  /// **'Master Search'**
  String get masterSearch;

  /// No description provided for @changeLanguage.
  ///
  /// In en, this message translates to:
  /// **'Change Language'**
  String get changeLanguage;

  /// No description provided for @switchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch Account'**
  String get switchAccount;

  /// No description provided for @sortMovies.
  ///
  /// In en, this message translates to:
  /// **'Sort Movies'**
  String get sortMovies;

  /// No description provided for @sortSeries.
  ///
  /// In en, this message translates to:
  /// **'Sort Series'**
  String get sortSeries;

  /// No description provided for @vpnConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get vpnConnected;

  /// No description provided for @vpnDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get vpnDisconnected;

  /// No description provided for @pasteConfContent.
  ///
  /// In en, this message translates to:
  /// **'Paste the contents of your .conf file below (e.g. from NordVPN or Surfshark).'**
  String get pasteConfContent;

  /// No description provided for @playlistName.
  ///
  /// In en, this message translates to:
  /// **'Playlist Name'**
  String get playlistName;

  /// No description provided for @editAccount.
  ///
  /// In en, this message translates to:
  /// **'Edit Account'**
  String get editAccount;

  /// No description provided for @continueWatching.
  ///
  /// In en, this message translates to:
  /// **'Continue Watching'**
  String get continueWatching;

  /// No description provided for @resumePlayback.
  ///
  /// In en, this message translates to:
  /// **'Resume Playback'**
  String get resumePlayback;

  /// No description provided for @resumeFrom.
  ///
  /// In en, this message translates to:
  /// **'Do you want to resume from'**
  String get resumeFrom;

  /// No description provided for @startOver.
  ///
  /// In en, this message translates to:
  /// **'Start Over'**
  String get startOver;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @favorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get favorites;

  /// No description provided for @noAccountsAdded.
  ///
  /// In en, this message translates to:
  /// **'No accounts added'**
  String get noAccountsAdded;

  /// No description provided for @episodes.
  ///
  /// In en, this message translates to:
  /// **'Episodes'**
  String get episodes;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @fullScreen.
  ///
  /// In en, this message translates to:
  /// **'Fullscreen'**
  String get fullScreen;

  /// No description provided for @fullWidth.
  ///
  /// In en, this message translates to:
  /// **'Full Width'**
  String get fullWidth;

  /// No description provided for @minimize.
  ///
  /// In en, this message translates to:
  /// **'Minimize'**
  String get minimize;

  /// No description provided for @vodPlayback.
  ///
  /// In en, this message translates to:
  /// **'VOD Playback'**
  String get vodPlayback;

  /// No description provided for @epgDrawer.
  ///
  /// In en, this message translates to:
  /// **'Channel List & EPG'**
  String get epgDrawer;

  /// No description provided for @nextChannel.
  ///
  /// In en, this message translates to:
  /// **'Next Channel'**
  String get nextChannel;

  /// No description provided for @previousChannel.
  ///
  /// In en, this message translates to:
  /// **'Previous Channel'**
  String get previousChannel;

  /// No description provided for @noProgramInfo.
  ///
  /// In en, this message translates to:
  /// **'No program info'**
  String get noProgramInfo;

  /// No description provided for @upNext.
  ///
  /// In en, this message translates to:
  /// **'Up Next'**
  String get upNext;

  /// No description provided for @manualSetup.
  ///
  /// In en, this message translates to:
  /// **'Manual Setup'**
  String get manualSetup;

  /// No description provided for @linkViaWeb.
  ///
  /// In en, this message translates to:
  /// **'Web / QR Code'**
  String get linkViaWeb;

  /// No description provided for @scanQrCode.
  ///
  /// In en, this message translates to:
  /// **'Scan QR Code'**
  String get scanQrCode;

  /// No description provided for @scanWithPhone.
  ///
  /// In en, this message translates to:
  /// **'Scan this QR code with your smartphone to upload your playlist remotely.'**
  String get scanWithPhone;

  /// No description provided for @deviceId.
  ///
  /// In en, this message translates to:
  /// **'Device ID'**
  String get deviceId;

  /// No description provided for @pairingPin.
  ///
  /// In en, this message translates to:
  /// **'Pairing PIN'**
  String get pairingPin;

  /// No description provided for @waitingForPlaylist.
  ///
  /// In en, this message translates to:
  /// **'Waiting for playlist...'**
  String get waitingForPlaylist;

  /// No description provided for @playlistReceived.
  ///
  /// In en, this message translates to:
  /// **'Playlist received! Loading...'**
  String get playlistReceived;

  /// No description provided for @newPin.
  ///
  /// In en, this message translates to:
  /// **'New PIN'**
  String get newPin;

  /// No description provided for @orVisitWebsite.
  ///
  /// In en, this message translates to:
  /// **'Or open this portal in any browser:'**
  String get orVisitWebsite;

  /// No description provided for @pinExpiresIn.
  ///
  /// In en, this message translates to:
  /// **'PIN expires in'**
  String get pinExpiresIn;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Copied!'**
  String get copied;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
