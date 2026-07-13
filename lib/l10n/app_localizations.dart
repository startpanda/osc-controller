import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../models/osc_models.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  bool get isZh => locale.languageCode == 'zh';

  static const supportedLocales = [
    Locale('zh'),
    Locale('en'),
  ];

  static List<LocalizationsDelegate<dynamic>> get delegates => [
    const _AppLocalizationsDelegate(),
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  String get appTitle => isZh ? 'OSC 控制面板' : 'OSC Control Panel';
  String get online => isZh ? '在线' : 'Online';
  String get sender => isZh ? '发送器' : 'Sender';
  String get receiver => isZh ? '接收器' : 'Receiver';
  String get ready => isZh ? '就绪' : 'Ready';
  String get openSoundControl => 'Open Sound Control';

  String get settings => isZh ? '设置' : 'Settings';
  String get about => isZh ? '关于' : 'About';
  String get aboutAuthor => '追风中年人';
  String get language => isZh ? '语言' : 'Language';
  String get chinese => '中文';
  String get english => 'English';

  String get sendTargets => isZh ? '发送目标' : 'Send Targets';
  String get add => isZh ? '添加' : 'Add';
  String get sendLog => isZh ? '发送日志' : 'Send Log';
  String get clear => isZh ? '清空' : 'Clear';
  String get noSendRecords => isZh ? '暂无发送记录' : 'No send records yet';

  String get commandSend => isZh ? '命令发送' : 'Command Send';
  String targetsEnabled(int count) =>
      isZh ? '$count 个目标已启用' : '$count target(s) enabled';
  String get commandHint => isZh
      ? '例如: /test ,f 20.3 或 /test f 20.3 或 /test 1 2.5 hello'
      : 'e.g. /test ,f 20.3 or /test f 20.3 or /test 1 2.5 hello';
  String get send => isZh ? '发送' : 'Send';

  String get controlPanel => isZh ? '控件面板' : 'Control Panel';
  String get addControl => isZh ? '添加控件' : 'Add Control';
  String get noControlsYet => isZh
      ? '还没有控件，点击"添加控件"开始创建'
      : 'No controls yet. Click "Add Control" to create one.';

  String get enabled => isZh ? '已启用' : 'Enabled';
  String get disabled => isZh ? '已禁用' : 'Disabled';
  String logTargets(int count) => isZh ? '→ $count 目标' : '→ $count target(s)';

  String get alert => isZh ? '提示' : 'Notice';
  String get ok => isZh ? '确定' : 'OK';

  String get importConfig => isZh ? '导入配置' : 'Import Configuration';
  String get exportConfig => isZh ? '导出配置' : 'Export Configuration';
  String get exportConfigSuccess =>
      isZh ? '配置已导出' : 'Configuration exported';
  String get importConfigSuccess =>
      isZh ? '配置已导入' : 'Configuration imported';
  String get importConfigInvalid =>
      isZh ? '配置文件无效或已损坏' : 'Invalid or corrupted configuration file';
  String get exportConfigFailed => isZh ? '导出失败' : 'Export failed';
  String get cancel => isZh ? '取消' : 'Cancel';
  String get confirmAdd => isZh ? '确认添加' : 'Add';
  String get saveChanges => isZh ? '保存修改' : 'Save';

  String get oscAddressMustStartWithSlash =>
      isZh ? 'OSC地址必须以 / 开头' : 'OSC address must start with /';
  String get enableAtLeastOneTarget =>
      isZh ? '请至少启用一个发送目标' : 'Enable at least one send target';
  String get sendFailed => isZh ? '发送失败' : 'Send failed';
  String get listenFailed => isZh ? '监听失败' : 'Listen failed';

  String get editSendTarget => isZh ? '编辑发送目标' : 'Edit Send Target';
  String get addSendTarget => isZh ? '添加发送目标' : 'Add Send Target';
  String get editSendTargetDesc => isZh
      ? '修改 OSC 发送目标的配置信息'
      : 'Update OSC send target settings';
  String get addSendTargetDesc => isZh
      ? '配置新的 OSC 消息发送目标'
      : 'Configure a new OSC send target';

  String get targetName => isZh ? '目标名称' : 'Target Name';
  String get targetNameHint => isZh ? '例如: 主控台' : 'e.g. Main Console';
  String get ipAddress => isZh ? 'IP 地址' : 'IP Address';
  String get port => isZh ? '端口' : 'Port';
  String get enterIpAndPort =>
      isZh ? '请输入IP地址和端口' : 'Enter IP address and port';

  String get editControl => isZh ? '编辑控件' : 'Edit Control';
  String get addControlTitle => isZh ? '添加新控件' : 'Add Control';
  String get editControlDesc =>
      isZh ? '修改控件的配置参数' : 'Update control parameters';
  String get addControlDesc =>
      isZh ? '配置新的 OSC 控件参数' : 'Configure a new OSC control';
  String get controlType => isZh ? '控件类型' : 'Control Type';
  String get labelName => isZh ? '标签名称' : 'Label';
  String get labelNameHint => isZh ? '控件标签' : 'Control label';
  String get oscAddress => isZh ? 'OSC 地址' : 'OSC Address';
  String get dataType => isZh ? '数据类型' : 'Data Type';
  String get minValue => isZh ? '最小值' : 'Min';
  String get maxValue => isZh ? '最大值' : 'Max';
  String get stepValue => isZh ? '步进值' : 'Step';
  String get defaultText => isZh ? '默认文本' : 'Default Text';
  String get defaultTextHint => isZh ? '默认文本...' : 'Default text...';
  String get newControl => isZh ? '新控件' : 'New Control';

  String get editListenPort => isZh ? '编辑监听端口' : 'Edit Listen Port';
  String get addListenPort => isZh ? '添加监听端口' : 'Add Listen Port';
  String get editListenPortDesc =>
      isZh ? '修改 OSC 监听端口号' : 'Change OSC listen port';
  String get addListenPortDesc =>
      isZh ? '添加新的 OSC 消息监听端口' : 'Add a new OSC listen port';
  String get portNumber => isZh ? '端口号' : 'Port Number';
  String get portNumberHint => isZh ? '例如: 9000' : 'e.g. 9000';
  String get enterPortNumber => isZh ? '请输入端口号' : 'Enter port number';
  String get portAlreadyExists => isZh ? '该端口号已存在' : 'Port already exists';

  String get listenPorts => isZh ? '监听端口' : 'Listen Ports';
  String get addPort => isZh ? '添加端口' : 'Add Port';
  String get liveDataStream => isZh ? '实时数据流' : 'Live Data Streams';
  String streamsCount(int count) =>
      isZh ? '$count 个数据流' : '$count stream(s)';
  String get clearAll => isZh ? '清空所有' : 'Clear All';
  String get stopListening => isZh ? '停止监听' : 'Stop';
  String get startListening => isZh ? '启动监听' : 'Start';
  String get graph => isZh ? '图形' : 'Graph';
  String get terminal => isZh ? '命令行' : 'Terminal';
  String get waitingForOsc =>
      isZh ? '等待接收 OSC 消息...' : 'Waiting for OSC messages...';
  String get startPortToSeeStreams => isZh
      ? '启动监听端口后将自动显示数据流'
      : 'Start a listen port to show streams';

  String portLabel(String port) => isZh ? '端口 $port' : 'Port $port';
  String get localTarget => isZh ? '本地' : 'Local';
  String get inputPlaceholder => isZh ? '输入...' : 'Enter...';
  String get pickColor => isZh ? '选择颜色' : 'Pick Color';

  String get toggleOffValue => isZh ? 'False 值' : 'Off Value';
  String get toggleOnValue => isZh ? 'True 值' : 'On Value';
  String get toggleDataTypeTf => isZh ? 'T / F（无参数）' : 'T / F (no value)';

  String get admObjectChannel => isZh ? '对象通道 n' : 'Object n';

  String controlTypeLabel(ControlType type) => switch (type) {
        ControlType.slider => isZh ? '滑块' : 'Slider',
        ControlType.toggle => isZh ? '开关' : 'Toggle',
        ControlType.button => isZh ? '按钮' : 'Button',
        ControlType.xyPad => isZh ? 'XY控制器' : 'XY Pad',
        ControlType.input => isZh ? '文本输入' : 'Text Input',
        ControlType.color => isZh ? '颜色选择器' : 'Color Picker',
        ControlType.admXyz => isZh ? 'ADM XYZ' : 'ADM XYZ',
        ControlType.admYpr => isZh ? 'ADM YPR' : 'ADM YPR',
        ControlType.admAed => isZh ? 'ADM AED' : 'ADM AED',
      };
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['zh', 'en'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async {
    return AppLocalizations(locale);
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) =>
      false;
}
