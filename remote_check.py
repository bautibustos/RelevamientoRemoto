import wmi, json

with open('credenciales.txt', 'r', encoding='utf-8') as file:
    aux = file.readlines()
    us = aux[0][:-1]
    pwd = aux[1]


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
    'disco':[]
}

def casi_completo(identificador):
    # Conexión a un equipo remoto
    c = wmi.WMI(identificador, user=us, password=pwd)#namespace="root\\Microsoft\\Windows\\Storage"

    for os in c.Win32_OperatingSystem():
        equipo['so']=os.Caption

    for cpu in c.Win32_Processor():
        #print(cpu)
        equipo['cpu']=cpu.Name

    for mother in c.Win32_BaseBoard():
        #print(mother)
        equipo['placa']=mother.Manufacturer, mother.Product

    ddr_map = {
        18: "DDR1", 
        19: "DDR2", 
        24: "DDR3", 
        26: "DDR4",
        34: "DDR5"
    }
    capacidad_ram = 0
    for memory in c.Win32_PhysicalMemory():
        #print(memory)
        cantidad_gb=round(int(memory.Capacity)/(1024**3))
        capacidad_ram = cantidad_gb + capacidad_ram
        #print(ddr_map[memory.SMBIOSMemoryType],
        #    memory.Speed, "capacidad del modulo: ", round(int(memory.Capacity)/(1024**3)))
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


def discos(identificador):

    c = wmi.WMI(identificador, user=us, password=pwd,namespace="root\\Microsoft\\Windows\\Storage")#
    for disk in c.MSFT_PhysicalDisk():
        #print(disk)
        capacidad = round(int(disk.Size) / (1024**3), 2)
        media_type = int(disk.MediaType)  
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
             
            print(explorer.GetOwner())

            # Devolvemos el nombre del usuario de la sesión activa
            # Formato: DOMINIO\Usuario o simplemente Usuario
            """ if dominio and dominio != identificador:
                 return f"{dominio}\\{nombre_usuario}"
            else:
                 return nombre_usuario"""
        else:
            # Esto puede significar que nadie tiene una sesión interactiva
            return "No hay sesión de escritorio activa (explorer.exe no encontrado)"

def ejecutor(identificador):
    casi_completo(identificador)
    discos(identificador)
    obtener_usuario(identificador)
    return(json.dumps(equipo, indent=4))



if __name__ == "__main__":
    print(ejecutor('PC0028'))

    
