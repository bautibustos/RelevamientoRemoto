import remote_check, exel_manager, os

path = 'files/'
busqueda = os.listdir(path=path)
for nombre in busqueda:
    # si es archivo
    if os.path.isfile(path+nombre) and nombre != 'no-listadas.txt':
        with open(path+nombre, 'r') as f:
            contenido = f.readlines()
        ubicacion = nombre[:-4]
        for nombre_archivo in contenido:
            print(nombre_archivo)
            #                                       se suprime los endline
            caracteristicas = remote_check.ejecutor(nombre_archivo[:-1])
            print(caracteristicas)
        print('a',ubicacion, contenido)

            
    