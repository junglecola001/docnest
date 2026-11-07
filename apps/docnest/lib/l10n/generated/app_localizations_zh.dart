// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'DocNest';

  @override
  String get navLibrary => '资料库';

  @override
  String get navSearch => '搜索';

  @override
  String get navTransfers => '传输';

  @override
  String get navSettings => '设置';

  @override
  String get libraryEmptyTitle => '还没有添加文件夹';

  @override
  String get libraryEmptyBody => '索引将在 M1 落地：加入白名单文件夹并完成扫描后，就在这里浏览、搜索和预览。';

  @override
  String get searchEmptyTitle => '搜索还没有接入';

  @override
  String get searchEmptyBody => '搜索在宿主的索引上执行，M1 完成索引数据库后可用。';

  @override
  String get transfersEmptyTitle => '没有传输任务';

  @override
  String get transfersEmptyBody => '配对与互传将在 M2、M3 落地。';

  @override
  String get settingsAppearance => '外观';

  @override
  String get settingsAccentColor => '强调色';

  @override
  String get settingsAccentColorHint => '一个颜色定义整个应用。';

  @override
  String get settingsColorStyle => '配色风格';

  @override
  String get styleVivid => '鲜明';

  @override
  String get styleTinted => '沉浸';

  @override
  String get styleSoft => '柔和';

  @override
  String get styleMonochrome => '单色';

  @override
  String get settingsThemeMode => '主题';

  @override
  String get themeSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get settingsGlass => '液态玻璃';

  @override
  String get settingsGlassOff => '关闭';

  @override
  String get settingsGlassStandard => '标准';

  @override
  String get settingsGlassUltra => '极致';

  @override
  String get settingsTextScale => '文字大小';

  @override
  String get settingsAbout => '关于';

  @override
  String settingsVersion(String version) {
    return '版本 $version';
  }
}
