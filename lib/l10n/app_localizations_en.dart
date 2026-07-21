// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'PIM';

  @override
  String get devicesTab => 'Devices';

  @override
  String get thisDevice => 'This device';

  @override
  String get onlineDevices => 'Devices on your network';

  @override
  String get noDevicesTitle => 'No devices found yet';

  @override
  String get noDevicesHint =>
      'Make sure other devices are on the same Wi-Fi network and have PIM open. Discovery happens automatically.';

  @override
  String get online => 'Online';

  @override
  String get offline => 'Offline';

  @override
  String get settings => 'Settings';

  @override
  String get deviceNameLabel => 'Device name';

  @override
  String get deviceNameHint => 'How this device appears to others';

  @override
  String get language => 'Language';

  @override
  String get systemDefault => 'System default';

  @override
  String get english => 'English';

  @override
  String get ukrainian => 'Ukrainian';

  @override
  String get save => 'Save';

  @override
  String get saved => 'Saved';

  @override
  String get identity => 'Identity';

  @override
  String get deviceId => 'Device ID';

  @override
  String get platformLabel => 'Platform';

  @override
  String get networkAddress => 'Address';

  @override
  String get chatHint => 'Type a message…';

  @override
  String get send => 'Send';

  @override
  String get emptyChatTitle => 'No messages yet';

  @override
  String emptyChatHint(String name) {
    return 'Send the first message to $name.';
  }

  @override
  String get sendFailed =>
      'Could not deliver the message. The device may have gone offline.';

  @override
  String get you => 'You';

  @override
  String get searching => 'Searching for devices…';

  @override
  String get appearance => 'Appearance';

  @override
  String get theme => 'Theme';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get yourAddress => 'Your address';

  @override
  String get notConnected => 'Not connected to a network';

  @override
  String get scanningNetwork => 'Scanning your Wi-Fi network…';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String deviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count devices',
      one: '1 device',
      zero: 'No devices',
    );
    return '$_temp0';
  }

  @override
  String get minimize => 'Minimize';

  @override
  String get maximize => 'Maximize';

  @override
  String get restore => 'Restore';

  @override
  String get close => 'Close';

  @override
  String coresLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cores',
      one: '1 core',
    );
    return '$_temp0';
  }

  @override
  String get processor => 'Processor';

  @override
  String get memory => 'Memory';

  @override
  String get system => 'System';

  @override
  String get specifications => 'Specifications';

  @override
  String get workspaces => 'Workspaces';

  @override
  String get createWorkspace => 'Create workspace';

  @override
  String get workspaceName => 'Workspace name';

  @override
  String get create => 'Create';

  @override
  String get cancel => 'Cancel';

  @override
  String get noWorkspacesTitle => 'No workspaces yet';

  @override
  String get noWorkspacesHint =>
      'Create a shared space and invite devices to exchange files.';

  @override
  String get members => 'Members';

  @override
  String get addDevice => 'Add device';

  @override
  String get sendFile => 'Send file';

  @override
  String get transfers => 'Transfers';

  @override
  String get noTransfers => 'No transfers yet';

  @override
  String get owner => 'Owner';

  @override
  String get leave => 'Leave';

  @override
  String get invite => 'Invite';

  @override
  String get inviteSent => 'Invitation sent';

  @override
  String invitePrefix(String name) {
    return '$name invites you to join';
  }

  @override
  String get accept => 'Accept';

  @override
  String get decline => 'Decline';

  @override
  String get noDevicesToAdd => 'No other devices found on your network.';

  @override
  String get sending => 'Sending';

  @override
  String get receiving => 'Receiving';

  @override
  String get completed => 'Completed';

  @override
  String get failed => 'Failed';

  @override
  String get rejected => 'Rejected';

  @override
  String get open => 'Open';

  @override
  String get openFolder => 'Open folder';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get content => 'Content';

  @override
  String get newFolder => 'New folder';

  @override
  String get folderName => 'Folder name';

  @override
  String get delete => 'Delete';

  @override
  String get rename => 'Rename';

  @override
  String get files => 'Files';

  @override
  String get emptyFolderTitle => 'This folder is empty';

  @override
  String get emptyFolderHint =>
      'Send a file or create a folder to get started.';

  @override
  String get deleteFolderConfirm =>
      'Delete this folder and everything inside it?';

  @override
  String get deleteFileConfirm => 'Remove this file from the workspace?';

  @override
  String get notes => 'Notes';

  @override
  String get tasks => 'Tasks';

  @override
  String get addNote => 'Add note';

  @override
  String get addTask => 'Add task';

  @override
  String get noteText => 'Note';

  @override
  String get taskText => 'Task';

  @override
  String get copy => 'Copy';

  @override
  String get copied => 'Copied to clipboard';

  @override
  String get share => 'Share';

  @override
  String get edit => 'Edit';

  @override
  String get noNotes => 'No notes yet';

  @override
  String get noTasks => 'No tasks yet';

  @override
  String get gridView => 'Grid';

  @override
  String get listView => 'List';

  @override
  String get dropToSend => 'Drop files to send';

  @override
  String get description => 'Description';

  @override
  String get category => 'Category';

  @override
  String get status => 'Status';

  @override
  String get statusTodo => 'To do';

  @override
  String get statusDoing => 'In progress';

  @override
  String get statusDone => 'Done';

  @override
  String get board => 'Board';

  @override
  String get overview => 'Overview';

  @override
  String get noCategory => 'No category';

  @override
  String get newTask => 'New task';

  @override
  String get statistics => 'Statistics';

  @override
  String get byType => 'By type';

  @override
  String get totalSize => 'Total size';

  @override
  String get workspaceSettings => 'Workspace settings';

  @override
  String get taskStatus => 'Task status';

  @override
  String get images => 'Images';

  @override
  String get videos => 'Videos';

  @override
  String get audio => 'Audio';

  @override
  String get otherFiles => 'Other';

  @override
  String get shareScreen => 'Share screen';

  @override
  String get sharingScreen => 'You are sharing your screen';

  @override
  String get stop => 'Stop';

  @override
  String get view => 'View';

  @override
  String screenShareOffer(String name) {
    return '$name is sharing their screen with you';
  }

  @override
  String get messages => 'Messages';

  @override
  String get remoteControl => 'Remote control';

  @override
  String get viewAndControl => 'View & control screen';

  @override
  String get viewAndControlHint => 'Watch this device\'s screen and control it';

  @override
  String get shareMyScreen => 'Share my screen';

  @override
  String get shareMyScreenHint =>
      'Let this device watch and control your screen';

  @override
  String get openChatHint => 'Send messages and files';

  @override
  String get connecting => 'Connecting…';

  @override
  String waitingForHost(String name) {
    return 'Waiting for $name to allow control…';
  }

  @override
  String controlRequest(String name) {
    return '$name wants to view and control your screen';
  }

  @override
  String get allow => 'Allow';

  @override
  String get deny => 'Deny';

  @override
  String get screenCaptureUnsupported =>
      'Screen sharing is only available on Windows for now';

  @override
  String get streamSettings => 'Stream settings';

  @override
  String get quality => 'Quality';

  @override
  String get resolution => 'Resolution';

  @override
  String get frameRate => 'Frame rate';

  @override
  String get fit => 'Fit';

  @override
  String get stretch => 'Stretch';
}
