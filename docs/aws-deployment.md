- created a release and a docker image
- uploaded the docker image to ecr (because I don't want to deal with dockerhub)
- spun up a new ec2 instance
- log in to instance via ssh
- install things
```bash
sudo yum install -y docker
sudo service docker start
sudo usermod -a -G docker $USER
```
- configure aws and get the image
```bash
aws configure # and fill in the credentials
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin <account-id>.dkr.ecr.us-east-1.amazonaws.com
docker pull <image uri>
docker run -d -p 80:3000 <image uri>

```



