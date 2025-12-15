from openpyxl import load_workbook
exel_save = 'salida.xlsx'
def carga_equipos(info_sistema, numero_fila):
    archivo = load_workbook(filename = exel_save)
    hoja = archivo['Hoja1']
    # WS
    hoja[f'A{numero_fila}'] = 0
    # Piso
    hoja[f'B{numero_fila}'] = 0
    #area 
    hoja[f'C{numero_fila}'] = 0
    # Sistema operativo
    hoja[f'D{numero_fila}'] = 0
    #Procesador-Marca
    hoja[f'E{numero_fila}'] = 0
    #Procesador-Generacion
    hoja[f'F{numero_fila}'] = 0
    #Procesador-GHz
    hoja[f'G{numero_fila}'] = 0
    #Mother-Marca
    hoja[f'H{numero_fila}'] = 0
    #Mother-Modelo
    hoja[f'I{numero_fila}'] = 0
    #Video
    hoja[f'J{numero_fila}'] = 0
    #RAM-Tecnologia
    hoja[f'K{numero_fila}'] = 0
    #RAM-Total
    hoja[f'L{numero_fila}'] = 0
    #RAM-Mhz
    hoja[f'M{numero_fila}'] = 0
    #RAM-Cant. Modulos
    hoja[f'N{numero_fila}'] = 0
    #SSD
    hoja[f'O{numero_fila}'] = 0
    #Marca-SSD
    hoja[f'P{numero_fila}'] = 0
    #HDD
    hoja[f'O{numero_fila}'] = 0
    #Marca-HDD
    hoja[f'P{numero_fila}'] = 0



    print()

    archivo.save(exel_save)


if __name__ == '__main__':
    carga_equipos()