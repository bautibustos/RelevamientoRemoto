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
        #print(cpu.Name)
        equipo['cpu']=cpu.Name

    for mother in c.Win32_BaseBoard():
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
        cantidad_gb=round(int(memory.Capacity)/(1024**3))
        capacidad_ram = cantidad_gb + capacidad_ram
        #print(ddr_map[memory.SMBIOSMemoryType],
        #    memory.Speed, "capacidad del modulo: ", round(int(memory.Capacity)/(1024**3)))
        equipo['memoria']['capacidad'].append(cantidad_gb)
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
        capacidad = round(int(disk.Size) / (1024**3), 2)
        media_type = int(disk.MediaType)  
        tipo_disco = "HDD" if media_type == 3 else "SSD"
        #print(f"{disk.Model} {tipo_disco} {capacidad}"

        equipo['disco'].append({
        'marca': disk.Model,
        'capacidad':capacidad,
        'tecnologia':tipo_disco
        })
 


def ejecutor(identificador):
    casi_completo(identificador)
    discos(identificador)
    return(json.dumps(equipo, indent=4))

if __name__ == "__main__":
    ejecutor('PC0001')
