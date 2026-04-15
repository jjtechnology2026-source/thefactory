import 'package:thefactory/tfhka.dart';
import 'package:serial_port_win32/serial_port_win32.dart';

Future<void> main() async {
  final p = Tfhka();
  print(SerialPort.getAvailablePorts());
  final ok = await p.openFpctrl('COM99');
  print('open=$ok envio=${p.envio}');
  if (!ok) return;
  final cmds = ['7','3','101','I0X'];
  for (final c in cmds) {
    final r = await p.sendCmd(c);
    print('$c => $r | envio=${p.envio}');
  }
  p.closeFpctrl();
}
