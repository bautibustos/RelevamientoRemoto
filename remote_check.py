import wmi
# Conexión a un equipo remoto
c = wmi.WMI("PC0006", user="DOMINIO\\USUARIO", password="REDACTADO")#namespace="root\\Microsoft\\Windows\\Storage"
# Ahora puedes consultar información de ese equipo con 'c'
for os in c.Win32_OperatingSystem():
    print('-----sistema-----')
    print(os.Caption)

for cpu in c.Win32_Processor():
    print('-----proce-----')
    print(cpu.Name)

for mother in c.Win32_BaseBoard():
    print('-----placa-----')
    print(mother.Manufacturer, mother.Product)

print('-----memoria-----')
ddr_map = {
    18: "DDR1", 
    19: "DDR2", 
    24: "DDR3", 
    26: "DDR4",
    34: "DDR5"
}

capacidad_ram = 0
for memory in c.Win32_PhysicalMemory():
    capacidad_ram = round(int(memory.Capacity)/(1024**3)) + capacidad_ram
    print(ddr_map[memory.SMBIOSMemoryType],
          memory.Speed, "capacidad del modulo: ", round(int(memory.Capacity)/(1024**3)))
print("total: ", capacidad_ram)

# --- Placa de Video (GPU) ---
print("-----Placa de Video-----")

for video in c.Win32_VideoController():
    nombre_gpu = video.Name    
    # Se muestra el nombre, el tipo estimado y la RAM
    print(f"{nombre_gpu}")

print("-----Discos-----")

c = wmi.WMI("PC0001", user="DOMINIO\\USUARIO", password="REDACTADO",namespace="root\\Microsoft\\Windows\\Storage")#
for disk in c.MSFT_PhysicalDisk():
    capacidad = round(int(disk.Size) / (1024**3), 2)
    media_type = int(disk.MediaType)  
    tipo_disco = "HDD" if media_type == 3 else "SSD"
    print(f"{disk.Model} {tipo_disco} {capacidad}")

