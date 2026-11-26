# Pendientes

Mejoras a agregar al sistema de relevamiento (anotadas el 25/11/2026).

## 1. Editar equipos ya cargados — falta el formulario
Poder corregir una PC o un monitor después de cargarlos.
- [x] API: `PATCH /api/v1/pc/{id}` (nombre, área, piso, red) y `PATCH /api/v1/monitores/{id}`
  (todos los datos; `"equipo_id": null` lo deja sin PC; `"interfaces"` reemplaza la lista).
- [ ] App: formulario de edición, abriéndolo con los datos actuales desde el detalle del equipo.
  Caso típico de monitores: pasar un monitor de una PC a otra o dejarlo "sin PC".

## 2. Feedback al cargar una PC — hecho (ping)
- [x] Al guardar una PC, la API le hace un ping y la app muestra un aviso: verde si respondió,
  ámbar si no (y la PC queda como "Sin respuesta").
- [ ] A futuro (no pedido todavía): disparar también el relevamiento completo por WMI para completar el hardware.

## 3. Versión web de escritorio (revisar)
Revisar cómo se ve y se usa la app en una pantalla grande.
- Hoy el contenido se limita a 560 px de ancho y queda centrado.
- Evaluar listas en tabla, menú lateral fijo y formularios en más columnas.

## 4. Revisar cómo se visualizan los monitores
Revisar la lista y el detalle de monitores.
- Lista actual: "Marca Modelo", una línea con "PC · Área · Piso" y las pulgadas en una etiqueta.
- Detalle actual: hoja inferior con pulgadas, número de serie, entradas, PC, área, piso y observaciones.

## 5. Revisión de credenciales (probar el 26/11/2026)
Las credenciales de WMI ahora se leen del `.env` (`WMI_USUARIO`, `WMI_PASSWORD`; ver `.env.example`).
- Prueba del 25/11: PC0001 responde al ping pero WMI da "Acceso denegado" con las credenciales
  del `.env`; con la sesión actual de Windows (sin credenciales) sí conecta.
- [x] Si el `.env` no tiene credenciales, se usa la sesión actual de Windows (probado con PC0001 el 26/11).
  Las credenciales anteriores quedaron comentadas en el `.env` porque WMI las rechazaba.
- [x] Causa del "Acceso denegado": el lector del `.env` borraba una comilla que es parte de la contraseña.
  Corregido el 26/11: solo se quitan comillas si envuelven todo el valor. Probado con PC0001.
- [ ] PC0026: el nombre no resuelve en la red; confirmar el nombre correcto.
- [ ] Cambiar la contraseña que quedó en el historial de git (estaba escrita en `remote_check.py`).
