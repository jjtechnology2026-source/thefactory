import Tfhka
import time


def _repr_result(value):
    if value is None:
        return "None"
    if isinstance(value, bool):
        return str(value)
    if isinstance(value, str):
        hex_codes = " ".join(f"0x{ord(ch):02X}" for ch in value)
        return f"str({value!r}) bytes=[{hex_codes}]"
    return repr(value)


def _enviar_y_reportar(printer, comando, esperar=0.25):
    result = printer.SendCmd(comando)
    envio = getattr(printer, "envio", "")
    print(f"CMD {comando!r}")
    print(f"  retorno: {_repr_result(result)}")
    print(f"  envio:   {envio}")
    envio_text = str(envio)
    if "Error:" in envio_text and "Error: 00" not in envio_text:
        print(f"  aviso:   el comando fue rechazado por la impresora/emulador")
    time.sleep(esperar)
    return result


def probar_impresora(puerto):
    print("Iniciando prueba de comunicación...")
    print("Objetivo: mostrar retorno real y ejecutar flujo fiscal mínimo")

    try:
        printer = Tfhka.Tfhka()
    except Exception as e:
        print("Error al instanciar Tfhka. Verifica el archivo Tfhka.py en este directorio.")
        print("Detalle: " + str(e))
        return

    print("Intentando abrir el puerto: " + puerto)
    if not printer.OpenFpctrl(puerto):
        print("Falla en apertura. Verifica cable, energía y nombre del puerto.")
        return

    print("Puerto abierto correctamente")

    try:
        status = printer.ReadFpStatus()
        print("Estado inicial: " + str(status))

        print("\nDiagnóstico del comando de reporte:")
        _enviar_y_reportar(printer, "I0X", esperar=1.0)

        print("\nFlujo fiscal mínimo (debería generar salida visible si el emulador lo acepta):")
        secuencia = [
            "@PRUEBA SDK PYTHON",
            " 000000030000001000ITEM EXENTO",
            "3",
            "101",
        ]

        for comando in secuencia:
            _enviar_y_reportar(printer, comando)

        status_final = printer.ReadFpStatus()
        print("\nEstado final: " + str(status_final))
    finally:
        printer.CloseFpctrl()
        print("Puerto cerrado correctamente")


if __name__ == "__main__":
    PUERTO = "COM99"
    probar_impresora(PUERTO)