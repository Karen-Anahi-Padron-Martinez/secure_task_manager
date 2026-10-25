# Reporte de Prácticas y Evidencias: Secure Task Manager con Flutter y Node.js

Este documento contiene la estructura completa del proyecto, las respuestas teóricas requeridas por el manual, la tabla de resultados de pruebas de seguridad y los espacios listos para adjuntar las capturas de pantalla de evidencias.

---

## 1. Verificación de Entorno y Servicios

### 1.1 Contenedor PostgreSQL con Docker Compose
> 📸 **[PEGA AQUÍ TU CAPTURA DE PANTALLA: Docker Desktop / `docker compose ps` con el contenedor `backend-db-1` en ejecución]**

### 1.2 Migración de Base de Datos con Prisma
> 📸 **[PEGA AQUÍ TU CAPTURA DE PANTALLA: Salida en terminal de `npx prisma migrate dev`]**

### 1.3 Verificación de Endpoint de Salud (`/health`)
> 📸 **[PEGA AQUÍ TU CAPTURA DE PANTALLA: Petición GET a `http://localhost:3000/health` respondiendo `{"status":"ok"}`]**

---

## 2. Pruebas Automatizadas

### 2.1 Pruebas Unitarias y de Integración Backend (Jest + Supertest)
Ejecutar en la carpeta `backend`:
```bash
npm test
```
![Pruebas Backend Jest](./docs/evidencias/backend_tests.png)

### 2.2 Pruebas Unitarias y de Widgets en Flutter
Ejecutar en la carpeta `mobile`:
```bash
flutter test
```
![Pruebas Flutter](./docs/evidencias/flutter_tests.png)

---

## 3. Ejercicio Práctico 19a: Rotación de Tokens, Detección de Reúso y Logout

Puedes ejecutar el script automatizado que realiza todas las pruebas de la sección 19a:
```powershell
powershell -ExecutionPolicy Bypass -File .\test_exercises.ps1
```

> 📸 **[PEGA AQUÍ TU CAPTURA DE PANTALLA: Salida completa del script `test_exercises.ps1` mostrando Tasks 1 a 4 y CRUD en verde]**

### 3.1 Detalle de Tareas del Ejercicio

#### Task 1 — Rotación de Refresh Token (Rotation)
- **Predicción:** Se espera que `/auth/refresh` retorne un código HTTP `200` y devuelva un nuevo par de tokens (`accessToken` y `refreshToken`). El nuevo refresh token debe ser diferente al original.
- **Resultado Obtenido:** Código HTTP `200`. Comparación de tokens: `different`.
- **Conclusión:** Se comprobó que cada uso exitoso de un refresh token invalida el anterior y genera una nueva credencial.

#### Task 2 — Detección de Reúso (Reuse Detection)
- **Predicción:** Si se intenta usar nuevamente el refresh token anterior que ya fue rotado, el servidor detectará el intento de robo o reuso de credenciales y revocará inmediatamente toda la familia de tokens asociada.
- **Resultado Obtenido:**
  - Intento con token viejo -> Código HTTP `401 Unauthorized`.
  - Intento posterior con el token más reciente de la familia -> Código HTTP `401 Unauthorized`.
- **Conclusión:** La detección de reuso revocó exitosamente toda la familia de sesiones activas.

#### Task 3 — Cierre de Sesión (Logout)
- **Predicción:** Al llamar a `/auth/logout` con un refresh token, el servidor revoca la familia correspondiente retornando `204 No Content`. Un intento posterior de refresh con ese token debe ser rechazado.
- **Resultado Obtenido:**
  - Petición de logout -> Código HTTP `204`.
  - Petición de refresh posterior -> Código HTTP `401`.
- **Conclusión:** El logout revoca efectivamente el estado de la sesión en el servidor.

#### Task 4 — Cierre de Todas las Sesiones (Logout-all)
- **Predicción:** Con múltiples sesiones iniciadas para un mismo usuario, invocar `/auth/logout-all` usando el Bearer token debe revocar todos los refresh tokens activos del usuario.
- **Resultado Obtenido:**
  - Petición `/auth/logout-all` -> Código HTTP `204`.
  - Refresh desde sesión 1 -> Código HTTP `401`.
  - Refresh desde sesión 2 -> Código HTTP `401`.
- **Conclusión:** Se revocan todas las sesiones activas en todos los dispositivos/clientes del usuario.

---

## 4. Tabla de Resultados (Checklist de Pruebas - Página 45-46)

| Prueba (Test) | Código Esperado | Resultado Obtenido | ¿Aprobado? (Pass?) |
|---|:---:|:---:|:---:|
| **Refresh with valid token** | 200 | 200 | **Pass** |
| **Refresh with old token** | 401 | 401 | **Pass** |
| **Refresh with newest token after reuse** | 401 | 401 | **Pass** |
| **Refresh after logout** | 401 | 401 | **Pass** |
| **Refresh after logout-all** | 401 | 401 | **Pass** |

---

## 5. Preguntas de Reflexión y Discusión (Sección 19a - Página 46)

### 1. ¿Por qué rotar los refresh tokens? (*Why rotate refresh tokens?*)
**Respuesta:**
La rotación de refresh tokens garantiza que cada token solo pueda ser utilizado una única vez. Si un atacante intercepta un refresh token en tránsito o en reposo, en el momento en que la víctima o el atacante lo utilice, el token quedará invalidado para el otro. Esto reduce dramáticamente la ventana de oportunidad para que una credencial filtrada sea explotada continuamente.

### 2. ¿Qué podría suceder si el servidor almacenara los refresh tokens en texto plano? (*What could happen if the server stored raw refresh tokens?*)
**Respuesta:**
Si la base de datos se ve comprometida mediante una inyección SQL, una filtración de respaldos, o acceso no autorizado a los logs/datos, el atacante obtendría tokens válidos directamente utilizables para personificar a los usuarios de inmediato sin requerir contraseñas. Al almacenar únicamente el hash SHA-256 de los refresh tokens, una base de datos expuesta no proporciona ningún token en texto plano que pueda ser presentado a la API.

### 3. ¿Por qué el reuso revoca a toda la familia de tokens? (*Why does reuse revoke the whole token family?*)
**Respuesta:**
Porque la presentación de un token que ya fue rotado es un síntoma claro de que una credencial fue duplicada o robada (bien sea que el atacante usó el token antiguo o la víctima intentó usar su token legítimo después de que el atacante ya rotó la sesión). Ante la imposibilidad del servidor de distinguir con certeza cuál de los dos actores es el legítimo, revocar a toda la familia de tokens corta el acceso inmediatamente a ambos, forzando un nuevo inicio de sesión completo y protegiendo los datos del usuario.

### 4. ¿Cuál es el compromiso (*trade-off*) si un cliente legítimo reintenta un refresh tras un fallo de red? (*What is the trade-off if a legitimate client retries a refresh after a network timeout?*)
**Respuesta:**
El compromiso está entre **disponibilidad/resiliencia de red** y **detección estricta de reuso**:
- Si el cliente envió una solicitud de refresh, el servidor la procesó y rotó el token en la BD, pero la respuesta de red se perdió antes de llegar al cliente, el cliente aún conserva el token viejo.
- Si el cliente reintenta la petición con ese token viejo, el servidor lo detectará como un reuso y revocará a toda la familia, cerrando la sesión de un usuario legítimo.
- Para mitigar esto, se requiere un manejo cuidadoso en el cliente: llamadas de refresh únicas (*single-flight*, compartiendo la misma promesa o `Future`), no reintentar automáticamente tras un fallo de red no autenticado, y si se requiere tolerancia a fallos, una ventana de gracia muy pequeña (pocos segundos) en el servidor para llamadas idénticas de refresco.

---

## 6. Evidencias del Cliente Móvil Flutter

### 6.1 Pantalla de Inicio de Sesión y Registro
![Flutter Sign In](./docs/evidencias/flutter_login.png)

### 6.2 Pantalla Principal de Tareas (CRUD de Tareas)
![Flutter Tasks](./docs/evidencias/flutter_tasks.png)
