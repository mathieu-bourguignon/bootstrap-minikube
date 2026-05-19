# Utiliser l'image Python de base
FROM python:3.12-slim

# Définir le répertoire de travail
WORKDIR /app

# Installer les dépendances
COPY requirements.txt /app/requirements.txt
RUN pip install --no-cache-dir -r requirements.txt

# Copier les fichiers locaux dans le conteneur
COPY . /app

# Exposer le port sur lequel Flask écoute
EXPOSE 5000

# Lancer l'application Flask
CMD ["python", "app.py"]
