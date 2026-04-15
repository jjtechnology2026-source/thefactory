import Tfhka
import time
import sys
import serial
def probar_impresora(puerto):
    print("Iniciando prueba de comunicación...")
    
    # 1. Declaración de un objeto tipo Tfhka [cite: 5437]
    try:
        printer = Tfhka.Tfhka()
    except Exception as e:
        print("Error al instanciar Tfhka. Asegúrate de tener el archivo Tfhka.py en este directorio.")
        print("Detalle: " + str(e))
        return

    # 2. Apertura del puerto [cite: 5442, 5443]
    print("Intentando abrir el puerto: " + puerto)
    if printer.OpenFpctrl(puerto):
        print("¡Puerto abierto exitosamente! [cite: 5448]")
        
        # 3. Leer estado de la impresora [cite: 5454]
        # Retorna una cadena de caracteres con el estado y el error [cite: 5458]
        status = printer.ReadFpStatus()
        print("Estado actual de la impresora: " + str(status))
        
        # 4. Enviar un comando de prueba (Reporte X) usando SendCmd [cite: 5460, 5461]
        # Imprimir un Reporte X es seguro ya que no afecta la contabilidad fiscal
        print("Enviando comando para imprimir Reporte X (I0X)...")
        comando_exitoso = printer.SendCmd("I0X")
        
        if comando_exitoso:
            print("Comando ejecutado exitosamente. [cite: 5465]")
            print("Por favor espera mientras la impresora termina...")
            time.sleep(5) # Damos tiempo a la impresora de procesar
        else:
            print("Error en ejecución del método SendCmd. [cite: 5466]")
            status_post_error = printer.ReadFpStatus()
            print("Status después del error: " + str(status_post_error))

        # 5. Cerrar el puerto [cite: 5450, 5451]
        printer.CloseFpctrl()
        print("Puerto cerrado correctamente.")
        
    else:
        print("Falla en apertura. [cite: 5449] Verifica el cable, la energía y el nombre del puerto.")

if __name__ == "__main__":
    # Cambia esto por el puerto real que estés usando (ej. "COM1" en Windows o "/dev/ttyUSB0" en Linux)
    PUERTO = "COM1" 
    probar_impresora(PUERTO)