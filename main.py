import remote_check, exel_manager, os, subprocess

path = 'files/'
busqueda = os.listdir(path=path)
for nombre in busqueda:
    # si es archivo
    if os.path.isfile(path+nombre) and nombre != 'no-listadas.txt':

        #leer el archivo
        with open(path+nombre, 'r') as f:
            contenido = f.readlines()
        ubicacion = nombre[:-4]

        #iterar sobre el contenido
        contador_para_fila = 1
        for nombre_equipo in contenido:

            # revision de que el equipo este andando
            ping = subprocess.run(
                ['ping', '-n', '1', '-w', '1000', nombre_equipo[:-1]], capture_output=True, text=True#
            )
            if ping.returncode == 0:
                contador_para_fila += 1
                #contador de fila 
                print(contador_para_fila)
                caracteristicas = remote_check.ejecutor(nombre_equipo[:-1])

                exel_manager.carga_equipos(
                    info_sistema=caracteristicas,
                    numero_fila=contador_para_fila,
                    detalles=[nombre_equipo, ubicacion.split()[0], ubicacion.split()[2], ubicacion.split()[4]]
                    )
            else:
                pass
            #                                       se suprime los endline

            
    