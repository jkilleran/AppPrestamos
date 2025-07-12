# Fotos de perfil en producción (Render, Heroku, etc.)

Actualmente, las fotos de perfil se guardan en la carpeta local `uploads/profiles/`.

**IMPORTANTE:**
- Plataformas como Render, Heroku, Vercel, etc. NO PERSISTEN archivos subidos localmente tras cada deploy o reinicio.
- Por eso, las fotos de perfil pueden dejar de estar disponibles y dar error 404.

## Solución recomendada para producción

1. **Usa un servicio externo de almacenamiento de archivos**, como:
   - Amazon S3
   - Cloudinary
   - Google Cloud Storage

2. **Guarda la URL pública** en la base de datos/campo `foto`.

3. **Ajusta el backend** para subir y servir imágenes desde ese servicio.

## Para pruebas locales
- La carpeta `uploads/profiles/` debe existir y estar accesible.
- Los archivos subidos solo estarán disponibles mientras el servidor local esté corriendo.

---

¿Dudas? Consulta la documentación oficial de tu proveedor o pide ayuda para migrar a S3/Cloudinary.
