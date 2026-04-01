# 🚀 Dotfiles & Linux Zero-Touch Provisioning

Ce dépôt public contient mes fichiers de configuration Linux (`stow`) ainsi que le moteur d'automatisation (`bootstrap.sh`) capable de réinstaller l'intégralité de ma machine à partir de zéro en une seule commande.

⚠️ **Sécurité** : Aucune donnée sensible, adresse IP locale ou mot de passe n'est stocké ici. Toutes les données privées, les clés SSH et les volumes lourds (Machines Virtuelles, Firefox, Mounts réseau) sont chiffrés de bout en bout et stockés dans OneDrive via **Restic** et **Bitwarden**.

---

## 🛠️ Prérequis de Restauration

Avant de lancer le script sur une machine vierge, vous devez posséder **3 notes sécurisées** dans votre coffre Bitwarden web :

1. `SSH GitHub` : Contient votre clé privée SSH (Base64) en note, et la clé publique en champ personnalisé "PUBLIC_KEY".
2. `Config Rclone` : Contient le token OneDrive généré par `rclone`.
3. `Restic Password` : Contient le mot de passe de déchiffrement de la base de données Restic.
4. `Network Config ` : Contient les DNS

---

## ⚡ Installation One-Click (Bootstrap)

Ouvrez un terminal sur la nouvelle machine (basée sur Arch Linux / CachyOS) et lancez :

```bash
curl -fsSL https://raw.githubusercontent.com/WillScarlettOhara/.dotfiles/master/bootstrap.sh | bash
```
