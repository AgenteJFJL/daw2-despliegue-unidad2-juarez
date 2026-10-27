JEAN FRANCO JUAREZ LOZANO

## En app.py:
La fecha no está escrita a mano: llega como variable de entorno (DEPLOY_DATE), que rellenará el User Data en el momento del despliegue.
Cambia los datos entre mayúsculas por los tuyos.
## en requeriments .txt:
gunicorn es un servidor WSGI de producción. El servidor de desarrollo de Flask (flask run) no debe usarse en producción.
## en Dockerfile:
Esto construye la imagen de Flask. Escucha en 0.0.0.0:5000 dentro del contenedor para que Nginx pueda alcanzarlo por la red Docker.
## en default.conf:
El primer bloque redirige todo a https, el segundo bloque temrina ssl y hace proxy inverso. 
## en user-data.sh:
Se automatiza la instalación para el