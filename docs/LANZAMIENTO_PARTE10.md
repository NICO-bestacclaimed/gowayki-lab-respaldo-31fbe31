# Preparación de lanzamiento

Responsable y contacto suministrados por el usuario: **sharon trujillo**,
**sharon.trujillo@tecsup.edu.pe**. Incorporados a privacidad y términos.
Los textos siguen siendo borradores: no se inventan plazos de conservación,
domicilio, entidad jurídica ni condiciones legales pendientes de revisión.

## Hosting y enlaces legales

`python tool/prepare_hosting.py --base-url https://gowayki-lab.web.app` genera
el candidato local sin publicar ni adjuntar APK. Los assets se verifican por
tamaño y SHA-256. Se conservan encabezados de seguridad y el bloqueo predeploy.
`node tool/check_hosting.mjs` debe rechazar este candidato mientras no esté
revisado y aprobado. No se ha desplegado Hosting.

`config/release-defines.example.json` contiene las URL propuestas. Usarlo con
`--dart-define-from-file` **solo después** de aprobar, publicar y comprobar
ambas páginas. Hasta entonces los enlaces legales permanecen desactivados
por defecto. El documento de ciudad usa un commit inmutable de GitHub cuya
descarga fue comprobada; no depende de publicar Hosting.

## App Distribution

Las notas actualizadas están en `docs/release-notes.txt`. Falta validar el
artefacto final y los flujos de `docs/PRUEBAS_FIREBASE_PARTE10.md` en dispositivo.
La lista de testers debe proporcionarse como archivo externo al repositorio.
`.gitignore` protege `testers*.txt`, `key.properties`, `.p12` y `.pfx`.

El comando de distribución documentado en `docs/OBSERVABILIDAD_9B.md` solo debe
ejecutarse tras autorización explícita del usuario para ese APK y esa lista.
No se subieron binarios, símbolos ni se invitaron testers en esta parte.

## Pendientes

- Revisión de políticas y datos de conservación/procedimiento de atención.
- Dispositivo Android para acceso, vinculación, sincronización y borrado.
- Validación nativa de mapas, permisos, alarmas y juego; iOS requiere Mac.
- El deep link opcional `gowayki://paradero/<id>` no se implementa en este bloque.
