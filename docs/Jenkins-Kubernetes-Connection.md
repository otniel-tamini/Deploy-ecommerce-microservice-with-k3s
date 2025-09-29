# Configuration de la connexion Jenkins → Kubernetes

Ce document explique comment configurer la connexion entre Jenkins et le cluster Kubernetes pour les déploiements automatisés.

## 🔧 Options de configuration

Le pipeline Jenkins supporte deux méthodes de déploiement automatiquement détectées :

### Option 1: kubectl Direct (Recommandée)
**Quand utiliser :** Jenkins est sur le même réseau que le cluster K3s ou a accès direct

#### Configuration requise :
1. **Installer kubectl sur Jenkins** :
   ```bash
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
   ```

2. **Configurer kubeconfig** :
   ```bash
   # Copier le kubeconfig depuis le master K3s
   scp root@192.168.2.232:/etc/rancher/k3s/k3s.yaml ~/.kube/config
   
   # Modifier l'IP dans le config
   sed -i 's/127.0.0.1/192.168.2.232/g' ~/.kube/config
   ```

3. **Ajouter kubeconfig aux credentials Jenkins** :
   - Type : `Secret file`
   - File : Le fichier kubeconfig
   - ID : `kubeconfig`

#### Test :
```bash
kubectl cluster-info
kubectl get nodes
```

### Option 2: SSH Deployment
**Quand utiliser :** Jenkins n'a pas accès direct au cluster K3s

#### Configuration requise :
1. **Clé SSH pour accès au master K3s** :
   ```bash
   ssh-keygen -t rsa -b 4096 -C "jenkins-deploy"
   ssh-copy-id prod-1@192.168.2.232
   ```

2. **Ajouter la clé SSH aux credentials Jenkins** :
   - Type : `SSH Username with private key`
   - Username : `prod-1`
   - Private Key : La clé privée générée
   - ID : `k8s-master-ssh`

3. **Installer sshagent plugin** dans Jenkins

#### Configuration du serveur cible :
Le serveur K3s master (192.168.2.232) doit avoir :
- kubectl configuré et fonctionnel
- Accès en écriture dans `/tmp/` pour l'utilisateur SSH
- Les permissions appropriées pour les opérations kubectl

## 🔍 Détection automatique

Le pipeline détecte automatiquement la méthode à utiliser :

```groovy
// Test if kubectl is available and configured
def kubectlAvailable = sh(
    script: 'kubectl version --client >/dev/null 2>&1',
    returnStatus: true
) == 0

if (kubectlAvailable) {
    env.DEPLOYMENT_METHOD = 'kubectl'
} else {
    env.DEPLOYMENT_METHOD = 'ssh'
}
```

## 📋 Processus de déploiement

### Méthode kubectl (directe) :
1. Copie du dossier k8s vers k8s-{environment}
2. Mise à jour des namespaces et images
3. Application directe via kubectl apply

### Méthode SSH :
1. Création d'un package tar.gz du dossier k8s
2. Copie SCP vers le serveur K3s master
3. Extraction et traitement sur le serveur distant
4. Application via kubectl sur le serveur distant
5. Nettoyage des fichiers temporaires

## 🎯 Avantages de chaque méthode

### kubectl Direct :
- ✅ Plus rapide
- ✅ Moins de complexité réseau
- ✅ Logs directs dans Jenkins
- ❌ Nécessite configuration réseau

### SSH Deployment :
- ✅ Fonctionne à travers les firewalls
- ✅ Isolation de sécurité
- ✅ Flexibilité d'architecture
- ❌ Légèrement plus lent
- ❌ Dépendance SSH

## 🔐 Sécurité

### Pour kubectl direct :
- Utiliser un ServiceAccount dédié avec RBAC limité
- Stocker kubeconfig dans Jenkins credentials (chiffré)
- Rotation régulière des tokens

### Pour SSH :
- Utiliser des clés SSH dédiées pour Jenkins
- Limiter les permissions de l'utilisateur SSH
- Audit des connexions SSH

## 🚨 Troubleshooting

### kubectl ne fonctionne pas :
```bash
# Vérifier la connectivité
kubectl cluster-info

# Vérifier les permissions
kubectl auth can-i create deployments --namespace=ecommerce-staging

# Vérifier le kubeconfig
echo $KUBECONFIG
cat ~/.kube/config
```

### SSH ne fonctionne pas :
```bash
# Tester la connexion SSH
ssh -T prod-1@192.168.2.232

# Vérifier les permissions kubectl sur le serveur distant
ssh prod-1@192.168.2.232 'kubectl get nodes'

# Vérifier les credentials Jenkins
# Aller dans Jenkins > Manage Jenkins > Manage Credentials
```

## 📊 Monitoring

Les deux méthodes incluent :
- Logs détaillés de déploiement
- Notifications Slack automatiques
- Validation pre et post-déploiement
- Nettoyage automatique des fichiers temporaires

## 🔄 Fallback

Si une méthode échoue, le pipeline :
1. Log l'erreur avec détails
2. Envoie une notification Slack d'échec
3. Marque le build comme FAILED
4. Nettoie les ressources temporaires

Cette approche garantit une flexibilité maximale selon votre infrastructure réseau.