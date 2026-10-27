import os
from flask import Flask

app = Flask(__name__)

@app.route("/")
def index():
    fecha = os.environ.get("DEPLOY_DATE", "desconocida")
    return f"""
    <html>
      <head><title>UT2-RA2</title></head>
      <body style="font-family: sans-serif; text-align: center; margin-top: 10%;">
        <h1>Despliegue Nginx + Flask + SSL</h1>
        <p><b>Alumno:</b> Jean FRanco Juarez Lozano</p>
        <p><b>Centro-Ciclo-Grupo:</b> Pío Baroja - DAW </p>
        <p><b>Fecha de despliegue:</b> {fecha}</p>
      </body>
    </html>
    """
