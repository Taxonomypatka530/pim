// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Ukrainian (`uk`).
class AppLocalizationsUk extends AppLocalizations {
  AppLocalizationsUk([String locale = 'uk']) : super(locale);

  @override
  String get appTitle => 'PIM';

  @override
  String get devicesTab => 'Пристрої';

  @override
  String get thisDevice => 'Цей пристрій';

  @override
  String get onlineDevices => 'Пристрої у вашій мережі';

  @override
  String get noDevicesTitle => 'Пристроїв поки не знайдено';

  @override
  String get noDevicesHint =>
      'Переконайтеся, що інші пристрої в тій самій Wi-Fi мережі та мають відкритий PIM. Пошук відбувається автоматично.';

  @override
  String get online => 'У мережі';

  @override
  String get offline => 'Не в мережі';

  @override
  String get settings => 'Налаштування';

  @override
  String get deviceNameLabel => 'Назва пристрою';

  @override
  String get deviceNameHint => 'Як цей пристрій бачать інші';

  @override
  String get language => 'Мова';

  @override
  String get systemDefault => 'Як у системі';

  @override
  String get english => 'Англійська';

  @override
  String get ukrainian => 'Українська';

  @override
  String get save => 'Зберегти';

  @override
  String get saved => 'Збережено';

  @override
  String get identity => 'Ідентифікація';

  @override
  String get deviceId => 'ID пристрою';

  @override
  String get platformLabel => 'Платформа';

  @override
  String get networkAddress => 'Адреса';

  @override
  String get chatHint => 'Введіть повідомлення…';

  @override
  String get send => 'Надіслати';

  @override
  String get emptyChatTitle => 'Повідомлень поки немає';

  @override
  String emptyChatHint(String name) {
    return 'Надішліть перше повідомлення до $name.';
  }

  @override
  String get sendFailed =>
      'Не вдалося доставити повідомлення. Можливо, пристрій вийшов з мережі.';

  @override
  String get you => 'Ви';

  @override
  String get searching => 'Пошук пристроїв…';

  @override
  String get appearance => 'Вигляд';

  @override
  String get theme => 'Тема';

  @override
  String get themeSystem => 'Системна';

  @override
  String get themeLight => 'Світла';

  @override
  String get themeDark => 'Темна';

  @override
  String get yourAddress => 'Ваша адреса';

  @override
  String get notConnected => 'Немає підключення до мережі';

  @override
  String get scanningNetwork => 'Сканування вашої Wi-Fi мережі…';

  @override
  String get today => 'Сьогодні';

  @override
  String get yesterday => 'Вчора';

  @override
  String deviceCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count пристрою',
      many: '$count пристроїв',
      few: '$count пристрої',
      one: '1 пристрій',
      zero: 'Немає пристроїв',
    );
    return '$_temp0';
  }

  @override
  String get minimize => 'Згорнути';

  @override
  String get maximize => 'Розгорнути';

  @override
  String get restore => 'Відновити';

  @override
  String get close => 'Закрити';

  @override
  String coresLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ядра',
      many: '$count ядер',
      few: '$count ядра',
      one: '1 ядро',
    );
    return '$_temp0';
  }

  @override
  String get processor => 'Процесор';

  @override
  String get memory => 'Пам\'ять';

  @override
  String get system => 'Система';

  @override
  String get specifications => 'Характеристики';

  @override
  String get workspaces => 'Простори';

  @override
  String get createWorkspace => 'Створити простір';

  @override
  String get workspaceName => 'Назва простору';

  @override
  String get create => 'Створити';

  @override
  String get cancel => 'Скасувати';

  @override
  String get noWorkspacesTitle => 'Просторів поки немає';

  @override
  String get noWorkspacesHint =>
      'Створіть спільний простір і запросіть пристрої для обміну файлами.';

  @override
  String get members => 'Учасники';

  @override
  String get addDevice => 'Додати пристрій';

  @override
  String get sendFile => 'Надіслати файл';

  @override
  String get transfers => 'Передачі';

  @override
  String get noTransfers => 'Передач поки немає';

  @override
  String get owner => 'Власник';

  @override
  String get leave => 'Вийти';

  @override
  String get invite => 'Запросити';

  @override
  String get inviteSent => 'Запрошення надіслано';

  @override
  String invitePrefix(String name) {
    return '$name запрошує вас до';
  }

  @override
  String get accept => 'Прийняти';

  @override
  String get decline => 'Відхилити';

  @override
  String get noDevicesToAdd => 'Інших пристроїв у вашій мережі не знайдено.';

  @override
  String get sending => 'Надсилання';

  @override
  String get receiving => 'Отримання';

  @override
  String get completed => 'Завершено';

  @override
  String get failed => 'Помилка';

  @override
  String get rejected => 'Відхилено';

  @override
  String get open => 'Відкрити';

  @override
  String get openFolder => 'Відкрити теку';

  @override
  String membersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count учасника',
      many: '$count учасників',
      few: '$count учасники',
      one: '1 учасник',
    );
    return '$_temp0';
  }

  @override
  String get content => 'Вміст';

  @override
  String get newFolder => 'Нова папка';

  @override
  String get folderName => 'Назва папки';

  @override
  String get delete => 'Видалити';

  @override
  String get rename => 'Перейменувати';

  @override
  String get files => 'Файли';

  @override
  String get emptyFolderTitle => 'Ця папка порожня';

  @override
  String get emptyFolderHint =>
      'Надішліть файл або створіть папку, щоб почати.';

  @override
  String get deleteFolderConfirm => 'Видалити цю папку та весь її вміст?';

  @override
  String get deleteFileConfirm => 'Прибрати цей файл з простору?';

  @override
  String get notes => 'Нотатки';

  @override
  String get tasks => 'Завдання';

  @override
  String get addNote => 'Додати нотатку';

  @override
  String get addTask => 'Додати завдання';

  @override
  String get noteText => 'Нотатка';

  @override
  String get taskText => 'Завдання';

  @override
  String get copy => 'Копіювати';

  @override
  String get copied => 'Скопійовано в буфер';

  @override
  String get share => 'Поділитися';

  @override
  String get edit => 'Редагувати';

  @override
  String get noNotes => 'Нотаток поки немає';

  @override
  String get noTasks => 'Завдань поки немає';

  @override
  String get gridView => 'Плитки';

  @override
  String get listView => 'Список';

  @override
  String get dropToSend => 'Відпустіть файли, щоб надіслати';

  @override
  String get description => 'Опис';

  @override
  String get category => 'Категорія';

  @override
  String get status => 'Статус';

  @override
  String get statusTodo => 'До виконання';

  @override
  String get statusDoing => 'В роботі';

  @override
  String get statusDone => 'Готово';

  @override
  String get board => 'Дошка';

  @override
  String get overview => 'Огляд';

  @override
  String get noCategory => 'Без категорії';

  @override
  String get newTask => 'Нове завдання';

  @override
  String get statistics => 'Статистика';

  @override
  String get byType => 'За типом';

  @override
  String get totalSize => 'Загальний розмір';

  @override
  String get workspaceSettings => 'Налаштування простору';

  @override
  String get taskStatus => 'Статус завдань';

  @override
  String get images => 'Зображення';

  @override
  String get videos => 'Відео';

  @override
  String get audio => 'Аудіо';

  @override
  String get otherFiles => 'Інше';

  @override
  String get shareScreen => 'Транслювати екран';

  @override
  String get sharingScreen => 'Ви транслюєте свій екран';

  @override
  String get stop => 'Зупинити';

  @override
  String get view => 'Дивитись';

  @override
  String screenShareOffer(String name) {
    return '$name транслює вам свій екран';
  }

  @override
  String get messages => 'Повідомлення';

  @override
  String get remoteControl => 'Віддалене керування';

  @override
  String get viewAndControl => 'Дивитись і керувати екраном';

  @override
  String get viewAndControlHint =>
      'Бачити екран цього пристрою та керувати ним';

  @override
  String get shareMyScreen => 'Транслювати мій екран';

  @override
  String get shareMyScreenHint =>
      'Дозволити цьому пристрою бачити ваш екран і керувати ним';

  @override
  String get openChatHint => 'Надсилати повідомлення та файли';

  @override
  String get connecting => 'Підключення…';

  @override
  String waitingForHost(String name) {
    return 'Очікуємо, поки $name дозволить керування…';
  }

  @override
  String controlRequest(String name) {
    return '$name хоче бачити ваш екран і керувати ним';
  }

  @override
  String get allow => 'Дозволити';

  @override
  String get deny => 'Відхилити';

  @override
  String get screenCaptureUnsupported =>
      'Трансляція екрана поки доступна лише на Windows';

  @override
  String get streamSettings => 'Налаштування трансляції';

  @override
  String get quality => 'Якість';

  @override
  String get resolution => 'Роздільність';

  @override
  String get frameRate => 'Кадри за секунду';

  @override
  String get fit => 'Вписати';

  @override
  String get stretch => 'Розтягнути';
}
