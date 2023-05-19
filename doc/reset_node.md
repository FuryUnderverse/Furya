# Tutorial to reset the node

### 1. Remove all runtime directories using the following command in the directory where you have the furya.env file

```bash
sudo rm -rf .furyad/
```

### 2. Pull and recreate the latest version of the furya image:

```
docker-compose pull furya && docker-compose up -d --force-recreate
```