# RelevamientoRemoto
Es un relevamiento remoto el cual utiliza los nombres o ip de equipos dentro de una red.


# planteo de uso
dentro de la carpeta files, se tienen que añadir archivos txt con el nombre de referencia, ya sea piso o area. Se levanta las ip o los nombres de los equipos dispuestos en red, se realiza un ping para saber si son posibles obtener informacion remotamente. Los que no respondan seran agregados en el archivo "no-listadas.txt".


# Modo doble API (cargar afuera, validar adentro)
Para cargar equipos desde una PC que no tiene acceso por WMI a los equipos, y que el
relevamiento lo haga otra PC que sí está dentro de la red. Las dos usan **la misma base**
(un archivo en una carpeta compartida) y se comunican a través de ella.

```
PC de afuera (MODO_API=carga)     inventario.db (compartida)       PC de adentro (VALIDADOR=1)
POST /pc  ───── guarda ─────►     estado = pendiente
                                         │  ◄──── reclama ─────    la marca como "relevando"
                                         │                         ping + WMI
la app consulta cada 3 s ◄─────   ok / sin_respuesta / error ◄──   guarda el resultado
```

**PC de adentro** (la que tiene la base y acceso WMI a los equipos), en su `.env`:
```
VALIDADOR=1
```
y se levanta la API como siempre. También se puede correr el validador solo: `python -m api.validador`.

**PC de afuera**, en su `.env`:
```
MODO_API=carga
INVENTARIO_DB=\\SERVIDOR01.dominio.local\d$\inv\db\inventario.db
```
En este modo la API no hace ping ni WMI: al cargar una PC (o al tocar "Volver a relevar") la
deja `pendiente` en la cola. El detalle de la PC en la app se actualiza solo y muestra
"En cola…", "Relevando en …" y el resultado final.

**Cómo se coordinan**
- Un validador toma una PC con `BEGIN IMMEDIATE` (bloqueo de escritura): dos validadores nunca
  toman la misma PC. Mientras la releva, la PC queda `pendiente` con `reclamado_por`/`reclamado_en`
  y la API la informa como `relevando`. Si el validador se corta, a los 10 minutos la PC vuelve a la cola.
- Cada validador anota un latido cada 15 s en la tabla `validadores`. `GET /api/v1/sistema`
  muestra el modo de la API, los validadores activos y cuántas PCs hay en cola.
- Las conexiones esperan hasta 30 s si la otra API está escribiendo, en lugar de fallar.
- La base usa el diario clásico de SQLite (nunca WAL, que no funciona en carpetas compartidas).

**Límites**
- SQLite sobre una carpeta compartida de Windows no es 100 % seguro con dos PCs escribiendo.
  Hacer copias de la base seguido. Lo más seguro es abrir el puerto de la API en la PC de adentro
  y usarla directamente por HTTP.
- El validador releva desde la PC de adentro: solo funciona con equipos a los que esa PC llega por WMI.
- Los vencimientos usan la hora de cada PC: tienen que tener la hora sincronizada (en dominio, lo está).
