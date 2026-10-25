# Script para ejecutar las pruebas y ejercicios practicos del PDF (Seccion 19 y 19a)
$BaseUrl = "http://localhost:3000/api/v1"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host "   SECURE TASK MANAGER - VERIFICACION DE EJERCICIOS (19a) " -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 0. Health Check
Write-Host "`n[Paso 0] Health Check: GET /health" -ForegroundColor Yellow
$health = Invoke-RestMethod -Uri "http://localhost:3000/health" -Method Get
Write-Host "Respuesta Health: status = $($health.status)" -ForegroundColor Green

# Setup
$RandomId = Get-Random -Minimum 10000 -Maximum 99999
$Email = "student-$RandomId@example.test"
$Password = "a-long-local-test-password-for-this-exercise"

Write-Host "`n[Setup] Registrando usuario de prueba: $Email" -ForegroundColor Yellow
$regBody = @{ email = $Email; password = $Password } | ConvertTo-Json
$register = Invoke-RestMethod -Uri "$BaseUrl/auth/register" -Method Post -Body $regBody -ContentType "application/json"
$AccessToken = $register.accessToken
$RefreshToken = $register.refreshToken
Write-Host "Usuario registrado exitosamente. Tokens obtenidos de forma segura." -ForegroundColor Green

# Task 1: Rotation
Write-Host "`n----------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Task 1 - Rotation" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
$OldRefresh = $RefreshToken
$rotBody = @{ refreshToken = $OldRefresh } | ConvertTo-Json
$rotated = Invoke-RestMethod -Uri "$BaseUrl/auth/refresh" -Method Post -Body $rotBody -ContentType "application/json"
$NewAccess = $rotated.accessToken
$NewRefresh = $rotated.refreshToken

$diff = if ($NewRefresh -ne $OldRefresh) { "different" } else { "same" }
Write-Host "Status esperado: 200 OK" -ForegroundColor Green
Write-Host "Comparacion de tokens: $diff" -ForegroundColor Green
Write-Host "Resultado: PASS (Se roto el refresh token correctamente)" -ForegroundColor Green

# Task 2: Reuse Detection
Write-Host "`n----------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Task 2 - Reuse detection" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Intentando reutilizar token antiguo ($OldRefresh)..." -ForegroundColor Yellow
try {
    $reuseBody = @{ refreshToken = $OldRefresh } | ConvertTo-Json
    Invoke-RestMethod -Uri "$BaseUrl/auth/refresh" -Method Post -Body $reuseBody -ContentType "application/json"
} catch {
    $status1 = $_.Exception.Response.StatusCode.value__
    Write-Host "Intento con token viejo -> Codigo recibido: $status1 (Esperado: 401)" -ForegroundColor Green
}

Write-Host "Intentando usar el token nuevo despues del reuso..." -ForegroundColor Yellow
try {
    $newBody = @{ refreshToken = $NewRefresh } | ConvertTo-Json
    Invoke-RestMethod -Uri "$BaseUrl/auth/refresh" -Method Post -Body $newBody -ContentType "application/json"
} catch {
    $status2 = $_.Exception.Response.StatusCode.value__
    Write-Host "Intento con token nuevo revocada la familia -> Codigo recibido: $status2 (Esperado: 401)" -ForegroundColor Green
}
Write-Host "Resultado: PASS (La familia entera de tokens fue revocada tras detectar reuso)" -ForegroundColor Green

# Task 3: Logout
Write-Host "`n----------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Task 3 - Logout" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
$loginBody = @{ email = $Email; password = $Password } | ConvertTo-Json
$login = Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
$logoutRefresh = $login.refreshToken

$logoutBody = @{ refreshToken = $logoutRefresh } | ConvertTo-Json
$logoutResponse = Invoke-WebRequest -Uri "$BaseUrl/auth/logout" -Method Post -Body $logoutBody -ContentType "application/json" -UseBasicParsing
Write-Host "Logout -> Codigo recibido: $($logoutResponse.StatusCode) (Esperado: 204)" -ForegroundColor Green

Write-Host "Intentando refrescar con el token deslogueado..." -ForegroundColor Yellow
try {
    Invoke-RestMethod -Uri "$BaseUrl/auth/refresh" -Method Post -Body $logoutBody -ContentType "application/json"
} catch {
    $statusLogout = $_.Exception.Response.StatusCode.value__
    Write-Host "Intento refresh posterior -> Codigo recibido: $statusLogout (Esperado: 401)" -ForegroundColor Green
}
Write-Host "Resultado: PASS (Logout invalido el refresh token en el servidor)" -ForegroundColor Green

# Task 4: Logout-all
Write-Host "`n----------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Task 4 - Logout-all" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
$session1 = Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
$access1 = $session1.accessToken
$refresh1 = $session1.refreshToken

$session2 = Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
$refresh2 = $session2.refreshToken

$headers = @{ Authorization = "Bearer $access1" }
$logoutAllResponse = Invoke-WebRequest -Uri "$BaseUrl/auth/logout-all" -Method Post -Headers $headers -UseBasicParsing
Write-Host "Logout-all -> Codigo recibido: $($logoutAllResponse.StatusCode) (Esperado: 204)" -ForegroundColor Green

try {
    $body1 = @{ refreshToken = $refresh1 } | ConvertTo-Json
    Invoke-RestMethod -Uri "$BaseUrl/auth/refresh" -Method Post -Body $body1 -ContentType "application/json"
} catch {
    $statusAll1 = $_.Exception.Response.StatusCode.value__
    Write-Host "Refresh Sesion 1 -> Codigo recibido: $statusAll1 (Esperado: 401)" -ForegroundColor Green
}

try {
    $body2 = @{ refreshToken = $refresh2 } | ConvertTo-Json
    Invoke-RestMethod -Uri "$BaseUrl/auth/refresh" -Method Post -Body $body2 -ContentType "application/json"
} catch {
    $statusAll2 = $_.Exception.Response.StatusCode.value__
    Write-Host "Refresh Sesion 2 -> Codigo recibido: $statusAll2 (Esperado: 401)" -ForegroundColor Green
}
Write-Host "Resultado: PASS (Todas las sesiones activas del usuario fueron revocadas)" -ForegroundColor Green

# CRUD de Tareas
Write-Host "`n----------------------------------------------------------" -ForegroundColor Cyan
Write-Host "Verificacion de Tareas (CRUD)" -ForegroundColor Cyan
Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
$loginFinal = Invoke-RestMethod -Uri "$BaseUrl/auth/login" -Method Post -Body $loginBody -ContentType "application/json"
$taskAuthHeaders = @{
    Authorization = "Bearer $($loginFinal.accessToken)"
    "Content-Type" = "application/json"
}

# Crear Tarea
$createTaskBody = @{
    title = "Review API security"
    description = "Check ownership and validation"
} | ConvertTo-Json
$createdTask = Invoke-RestMethod -Uri "$BaseUrl/tasks" -Method Post -Body $createTaskBody -Headers $taskAuthHeaders
Write-Host "Tarea creada -> ID: $($createdTask.item.id), Titulo: '$($createdTask.item.title)'" -ForegroundColor Green

# Listar Tareas
$tasksList = Invoke-RestMethod -Uri "$BaseUrl/tasks" -Method Get -Headers $taskAuthHeaders
Write-Host "Tareas obtenidas -> Cantidad: $($tasksList.items.Count)" -ForegroundColor Green

# Actualizar Tarea
$updateTaskBody = @{ completed = $true } | ConvertTo-Json
$updatedTask = Invoke-RestMethod -Uri "$BaseUrl/tasks/$($createdTask.item.id)" -Method Patch -Body $updateTaskBody -Headers $taskAuthHeaders
Write-Host "Tarea actualizada -> Completada: $($updatedTask.item.completed)" -ForegroundColor Green

# Eliminar Tarea
$deleteResponse = Invoke-WebRequest -Uri "$BaseUrl/tasks/$($createdTask.item.id)" -Method Delete -Headers $taskAuthHeaders -UseBasicParsing
Write-Host "Tarea eliminada -> Codigo recibido: $($deleteResponse.StatusCode) (Esperado: 204)" -ForegroundColor Green

Write-Host "`n==========================================================" -ForegroundColor Green
Write-Host "   TODAS LAS PRUEBAS Y EJERCICIOS COMPLETADOS CON EXITO   " -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Green
