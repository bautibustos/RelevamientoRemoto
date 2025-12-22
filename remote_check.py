import wmi, json, subprocess
with open('credenciales.txt', 'r', encoding='utf-8') as file:
    aux = file.readlines()
    us = aux[0][:-1]#borra un salto de linea
    pwd = aux[1]

# estrucutura de datos

equipo = {
    'so':None,
    'cpu':None,
    'placa':None,
    'memoria':{'ddr':None,
               'capacidad':[],
               'mhz':None,
               'total':None
               },
    'video': None,
    'disco':[],
    'Usuario':None
}
def cleaner():
    global equipo
    equipo.clear()
    equipo={
    'so':None,
    'cpu':None,
    'placa':None,
    'memoria':{'ddr':None,
               'capacidad':[],
               'mhz':None,
               'total':None
               },
    'video': None,
    'disco':[],
    'Usuario':None
}

def casi_completo(identificador):
    # Conexión a un equipo remoto
    c = wmi.WMI(identificador, user=us, password=pwd)#namespace="root\\Microsoft\\Windows\\Storage"
    # obtension de valores desde "c" que es la informacion del equipo completo
    
    for os in c.Win32_OperatingSystem():
        equipo['so']=str(os.Caption)

    for cpu in c.Win32_Processor():
        equipo['cpu']=str(cpu.name).split()

    for mother in c.Win32_BaseBoard():
        #print(mother)
        equipo['placa']=mother.Manufacturer, mother.Product

    # mapa para las RAMS, ya que se retorna un entero y no su tipo como tal.
    ddr_map = {
        18: "DDR1", 
        19: "DDR2", 
        24: "DDR3", 
        26: "DDR4",
        34: "DDR5"
    }
    #contador para ram total
    capacidad_ram = 0
    for memory in c.Win32_PhysicalMemory():
        #print(memory)
        # potencia 1024 a la 3 para calcular la cantidad de GBs ya que se retornan en kbs
        cantidad_gb=round(int(memory.Capacity)/(1024**3))
        capacidad_ram = cantidad_gb + capacidad_ram
        #print(ddr_map[memory.SMBIOSMemoryType],
        #    memory.Speed, "capacidad del modulo: ", round(int(memory.Capacity)/(1024**3)))

        # esto guarda la cantidad de modulos .
        equipo['memoria']['capacidad'].append(cantidad_gb)

    """
    Esto sirve para ver los slots de RAM. No es confiable 
    ya que toma el valor desde un chip el cual puede o no ser lo mismo que la cantidad de slots fisicos 
    
    for cantidad_slots in c.Win32_PhysicalMemoryArray():
        print(cantidad_slots.MemoryDevices)
        """

    equipo['memoria']['ddr']=ddr_map[memory.SMBIOSMemoryType]
    equipo['memoria']['mhz']=memory.Speed
    equipo['memoria']['total']=capacidad_ram

    # --- Placa de Video (GPU) ---
    for video in c.Win32_VideoController():
        nombre_gpu = video.Name    
        # Se muestra el nombre, el tipo estimado y la RAM
    equipo['video']=nombre_gpu

# la funcion discos se separa ya que utiliza otro parametro que la funcion anterior no necesita y probooca error
def discos(identificador):

    c = wmi.WMI(identificador, user=us, password=pwd,namespace="root\\Microsoft\\Windows\\Storage")#
    for disk in c.MSFT_PhysicalDisk():
        #print(disk)
        #se calcula la capacidad
        capacidad = round(int(disk.Size) / (1024**3), 2)
        media_type = int(disk.MediaType) # se utiliza para saber que tipo de disco es en la logica de abajo
        tipo_disco = "HDD" if media_type == 3 else "SSD"
        #print(f"{disk.Model} {tipo_disco} {capacidad}"

        equipo['disco'].append({
        'marca': disk.Model,
        'capacidad':capacidad,
        'tecnologia':tipo_disco
        })
 
def obtener_usuario(identificador):
    # 1. Conexión estándar
    c = wmi.WMI(identificador, user=us, password=pwd)

        # 2. Buscar el proceso explorer.exe
        # Esto devuelve una lista de procesos con ese nombre
    explorer_processes = c.Win32_Process(name='explorer.exe')

    if explorer_processes:
            # 3. Tomar el primer proceso de explorer.exe encontrado
        explorer = explorer_processes[0]
            
            # 4. Usar el método GetOwner() para obtener el dominio y el usuario
            # GetOwner() devuelve una tupla (Dominio, Nombre_Usuario)
             
        cuil = explorer.GetOwner()
        obtener_nombre = subprocess.run(f'net users {cuil[2]} /domain', capture_output=True, text=True)
            # Devolvemos el nombre del usuario de la sesión activa
            # Formato: DOMINIO\Usuario o simplemente Usuario

        for valor in obtener_nombre.stdout.splitlines():
            if "Nombre completo" in valor:
                nombre = valor.replace("Nombre completo", "").strip()
                equipo['Usuario'] = nombre
    else:
        # Esto puede significar que nadie tiene una sesión interactiva
        equipo['Usuario'] = 'N/A'

def ejecutor(identificador, user = True):
    cleaner()
    casi_completo(identificador)
    discos(identificador)
    if user:
        obtener_usuario(identificador)
    
    return equipo


if __name__ == "__main__":
    print(ejecutor('PC0003'))
    print(ejecutor('PC0004'))

    
