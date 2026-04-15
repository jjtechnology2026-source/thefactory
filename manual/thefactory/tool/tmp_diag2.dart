import 'package:thefactory/tfhka.dart';

Future<void> main() async {
  final p = Tfhka();
  final ok = await p.openFpctrl('COM99');
  print('open=$ok');
  if (!ok) return;
  final cmds = ['80PRUEBA','810FIN','I0X'];
  for (final c in cmds) {
    final r = await p.sendCmd(c);
    print('$c => $r | ${p.envio}');
  }
  p.closeFpctrl();
}
