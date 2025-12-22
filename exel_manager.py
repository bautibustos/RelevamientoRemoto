from openpyxl import load_workbook

exel_save = 'salida.xlsx'
def carga_equipos(info_sistema, numero_fila, detalles):
    archivo = load_workbook(filename = exel_save)
    hoja = archivo['Hoja1']
    # WS
    hoja[f'A{numero_fila}'] = detalles[0]
    # Piso
    hoja[f'B{numero_fila}'] = detalles[1]
    #area  
    hoja[f'C{numero_fila}'] = detalles[2]
    # Sistema operativo
    hoja[f'D{numero_fila}'] = info_sistema['so']
    #Procesador-Marca             ['Intel(R)', 'Core(TM)', 'i5-10400F', 'CPU', '@', '2.90GHz']
    hoja[f'E{numero_fila}'] = str(info_sistema['cpu'][0]+' '+info_sistema['cpu'][1])
    #Procesador-Generacion
    hoja[f'F{numero_fila}'] = info_sistema['cpu'][2]
    #Procesador-GHz
    hoja[f'G{numero_fila}'] = info_sistema['cpu'][5]
    #Mother-Marca
    hoja[f'H{numero_fila}'] = info_sistema['placa'][0]
    #Mother-Modelo
    hoja[f'I{numero_fila}'] = info_sistema['placa'][1]
    #Video
    hoja[f'J{numero_fila}'] = info_sistema['video']
    #RAM-Tecnologia
    hoja[f'K{numero_fila}'] = info_sistema['memoria']['ddr']
    #RAM-Total
    hoja[f'L{numero_fila}'] = info_sistema['memoria']['total']
    #RAM-Mhz
    hoja[f'M{numero_fila}'] = info_sistema['memoria']['mhz']
    #RAM-Cant. Modulos
    hoja[f'N{numero_fila}'] = str(info_sistema['memoria']['capacidad'])
    
    # logica para discos ssd 
    ssd = []
    hdd = []
    for disco in info_sistema['disco']:
        if disco['tecnologia'] =='SSD':
            ssd.append([disco['capacidad'], disco['marca']])

        elif disco['tecnologia'] =='HHD':
            hdd.append([disco['capacidad'], disco['marca']])

    # --- Lógica para SSD ---
    # capacidad
    hoja[f'O{numero_fila}'] = float(ssd[0][0]) if ssd else 0
    #marca 
    hoja[f'P{numero_fila}'] = str(ssd[0][1]) if ssd else 'nan'

    # --- Lógica para HDD ---
    hoja[f'Q{numero_fila}'] = float(hdd[0][0]) if hdd else 0
    hoja[f'R{numero_fila}'] = str(hdd[0][1]) if hdd else 'nan'

    #red
    hoja[f'S{numero_fila}'] = detalles[3]
    #usuario

    hoja[f'T{numero_fila}'] = info_sistema['Usuario']
    

    archivo.save(exel_save)


if __name__ == '__main__':
    carga_equipos()