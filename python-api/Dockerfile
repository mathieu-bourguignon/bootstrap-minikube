# Utiliser l'image Python de base
FROM python:3.12-slim

# Définir le répertoire de travail
WORKDIR /app

# Copier les fichiers locaux dans le conteneur
COPY . /app

# Installer les dépendances
RUN pip install Flask

# Exposer le port sur lequel Flask écoute
EXPOSE 5000

# Lancer l'application Flask
CMD ["python", "app.py"]