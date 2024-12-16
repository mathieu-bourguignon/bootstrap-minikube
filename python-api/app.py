import random
import time
from flask import Flask

app = Flask(__name__)

@app.route('/', methods=['GET'])
def generate_load():
    # Générer un délai aléatoire entre 20ms et 2s
    delay = random.uniform(0.02, 2.0)  # En secondes
    end_time = time.time() + delay

    # Simuler un traitement CPU en utilisant un calcul lourd
    while time.time() < end_time:
        _ = random.random() * random.random() * random.random() * random.random()

    return f"Load generated for {delay:.2f} seconds"

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)