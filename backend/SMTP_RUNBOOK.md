# SMTP Runbook (Gmail + Nodemailer)

Objetivo: Recuperar el envío de correos (adjuntos y test) sin timeouts.

---
## 1. Conceptos Clave
- Puerto 465 + `secure=true` = TLS implícito (conecta cifrado desde el inicio).
- Puerto 587 + `secure=false` = STARTTLS (texto plano inicial, luego negocia TLS). Recomendado para Gmail.
- `transporter.verify()` comprueba credenciales y handshake, NO envía correo.
- Timeouts iniciales (sin handshake) indican: DNS, firewall, bloqueo de puerto, caída de red o IP bloqueada.
- `EAUTH` / `Invalid login` = credenciales incorrectas (App Password inválido o usuario equivocado).

---
## 2. Variables de Entorno Recomendadas (Gmail) 
```
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_SECURE=false       # (STARTTLS)
SMTP_USER=tu_usuario@gmail.com
SMTP_PASS=16CARACTERESAPPASSWORD   # sin espacios
MAIL_FROM=tu_usuario@gmail.com     # opcional (remitente por defecto)
DOCUMENT_TARGET_EMAIL=destino@tu_dominio.com

# Resiliencia / fallback
SMTP_ENABLE_FALLBACK=1             # Activa lógica fallback
SMTP_FORCE_FALLBACK=1              # (Temporal) fuerza intentar config alternativa
SMTP_FALLBACK_PORT=465
SMTP_FALLBACK_SECURE=true

# Cola / degradación
EMAIL_ASYNC=0                      # 0 = intento directo, 1 = siempre cola
EMAIL_ASYNC_ON_FAIL=1              # Degradar a cola si timeout/conexión
SMTP_HARD_TIMEOUT=25000            # Corte "duro" del Promise.race

# Debug (solo temporal en diagnóstico)
UPLOAD_DEBUG=1
LOG_REQUESTS=0
```

Después de cambiar: reinicia el proceso Node.

---
## 3. Secuencia de Diagnóstico
1. GET `/smtp-health-extended`
   - `primary.dns_addresses`: Debe listar IPs. Si falta → problema DNS.
   - `primary.socket.connected=true`: Si falla → firewall/puerto bloqueado.
   - `primary.verify=true`: Handshake y auth OK.
   - `primary.verify_error` con `Invalid login` → revisar App Password.
2. GET `/email-config` (como admin)
   - Verifica `targetResolved` y `fromResolved`.
3. GET `/smtp-health`
   - Sólo latencia y verify básico para confirmar consistencia.
4. GET `/test-email` (autenticado) 
   - Debe devolver `{ ok:true }`. Si falla pero health pasaba, puede ser política de envío: revisa `MAIL_FROM` y Gmail (no usar From arbitrario si Gmail lo bloquea).
5. POST `/send-document-email` con un archivo pequeño: 
   - Respuesta rápida `ok:true`.
   - Si `queued:true,degraded:true` → conexión lenta, pero usuario no ve error. Revisa logs para entrega posterior.

---
## 4. Interpretación de Errores
| Síntoma | Causa probable | Acción |
|--------|----------------|--------|
| `SOCKET_TIMEOUT_5s` (extended) | Puerto bloqueado / firewall | Probar otro puerto, verificar salida 587/465 en hosting, usar `nc -vz smtp.gmail.com 587` |
| `DNS_FAIL` | Host mal escrito / DNS local | Revisar `SMTP_HOST` y resolver manualmente `dig smtp.gmail.com` |
| `VERIFY_FAIL` + `Invalid login` | App Password inválido | Regenerar en Cuenta Google > Seguridad > Contraseñas de aplicaciones |
| `VERIFY_FAIL` + `timeout` | Puerto / secure mismatch | Usar 587 + SECURE=false o 465 + SECURE=true correctamente |
| `EAUTH` directo en envío | Credenciales erróneas | Igual que arriba |
| `Timeout enviando email` (respuesta 500) | Falta `EMAIL_ASYNC_ON_FAIL=1` para degradar | Activar bandera o usar `EMAIL_ASYNC=1` |

---
## 5. Regenerar App Password (Gmail)
1. Cuenta Google > Seguridad > Verificación en dos pasos (activada).
2. "Contraseñas de aplicaciones" → Seleccionar "Mail" y "Otro" → Nombre (ej: PrestamosBackend).
3. Copiar EXACTAMENTE los 16 caracteres (sin espacios) en `SMTP_PASS`.
4. Invalidar el antiguo (se revoca automáticamente al cerrar modal).
5. Reiniciar backend.

---
## 6. Pruebas de Red Manuales (opcional shell)
```
# Verificar resolución DNS
nslookup smtp.gmail.com

# Verificar apertura de puerto 587
nc -vz smtp.gmail.com 587

# Handshake STARTTLS manual (Ctrl+C tras ver 220)
openssl s_client -starttls smtp -crlf -connect smtp.gmail.com:587
```
Si `nc` no conecta, el problema NO es la app.

---
## 7. Estrategia de Fallback
- Primario: 587 / STARTTLS (más tolerante proxies).
- Fallback: 465 / TLS implícito.
- Con `SMTP_FORCE_FALLBACK=1`, se probará siempre la alternativa tras fallo de conexión/timeout.

---
## 8. Modo Cola vs Directo
| Modo | Pros | Contras |
|------|------|---------|
| Directo (EMAIL_ASYNC=0) | Feedback inmediato; logs alineados | Usuario sufre latencia si SMTP lento |
| Cola (EMAIL_ASYNC=1) | UX instantánea | Entrega no verificada al usuario; requiere monitoreo |
| Directo + Degradación (EMAIL_ASYNC_ON_FAIL=1) | Intenta rápido y se degrada en fallo | Lógica algo más compleja |

Recomendado producción: `EMAIL_ASYNC=0` y `EMAIL_ASYNC_ON_FAIL=1` (equilibrio).

---
## 9. Checklist Final para "Funciona como antes"
[ ] `.env` actualizado con puerto 587 y `SMTP_SECURE=false`
[ ] App Password nuevo (16 chars) en `SMTP_PASS`
[ ] Reinicio del backend
[ ] `/smtp-health-extended` muestra `verify=true`
[ ] `/test-email` responde `ok:true`
[ ] Subida de documento responde `ok:true`
[ ] Logs muestran `Email enviado OK` (o fallback exitoso)

---
## 10. Próximas Mejores Prácticas (Opcional)
- Persistir cola en DB (tabla `email_outbox`).
- Reintentos con backoff exponencial.
- Métricas Prometheus (cuentas de éxitos/fallos).
- Mover archivos grandes a almacenamiento externo y sólo mandar enlace.

---
## 11. Soporte Rápido
Si tras todo lo anterior sigue fallando:
1. Captura JSON de `/smtp-health-extended`.
2. Copia transporter config (sin pass) de logs `[UPLOAD]`.
3. Indica resultado de `nc -vz smtp.gmail.com 587`.
4. Revisa si algún antivirus / firewall corporativo intercepta TLS.

Con eso se aísla 99% de los casos.
