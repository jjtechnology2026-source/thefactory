import 'package:serial_port_win32/serial_port_win32.dart';
import 'package:thefactory/tfhka.dart';

Future<void> main() async {
  final ports = SerialPort.getAvailablePorts();
  print('ports=$ports');
  for (final port in ports) {
    final p = Tfhka();
    final opened = await p.openFpctrl(port);
    if (!opened) {
      print('$port open=false');
      continue;
    }
    final status = await p.readFpStatus();
    final res = await p.sendCmd('7');
    print('$port status=$status write=$res envio=${p.envio}');
    p.closeFpctrl();
  }
}
