搭建邮件前先做环境测试
因为很多机房禁止对外发送邮件的 以下命令可以测试
traceroute -n -T -p 25 gmail-smtp-in.l.google.com   



安装系统 Ubuntu 14.04 LTS 
主要参考目录下的这2个文档
利用Docker自建多功能加密邮件服务器
快速搭建全功能 Mail server IMAP/SMTP w/ SSL
项目地址 https://github.com/tomav/docker-mailserver/wiki/Debugging

配置完可以到这个网站检测下评分
https://www.checktls.com/TestReceiver
http://www.mail-tester.com


首先安装docker 







git clone https://github.com/tomav/docker-mailserver.git
mv docker-compose.yml.dist  docker-compose.yml
修改这个文件 
在  volumes:
 - /home/mail:/var/mail
 - /home/mail-state:/var/mail-state
 - /root/config/:/tmp/docker-mailserver/
 - /etc/letsencrypt:/etc/letsencrypt
 
 添加  - /etc/letsencrypt:/etc/letsencrypt  目录是  容器可以挂载证书文件
 
 做改动如下，注意hostname和domainname，他俩最终要能拼成正规的主机
 
 
 ./setup.sh email add nykma@example.com PassW0rd!
./setup.sh email list # 应该能看到 nykma@example.com
./setup.sh alias add @example.com nykma@example.com
./setup.sh alias list # 应该能看到 @example.com nykma@example.com,
docker run --rm -v "$(pwd)/config":/tmp/docker-mailserver -it tvial/docker-mailserver:latest generate-dkim-config


然后去 ./config/opendkim/keys/example.com 找个txt，照着内容添加对应的DNS的TXT记录。注意你最终填进DNS提供商里的TXT应该是这文件里两个字符串拼起来的结果，结果中是没有引号的。类似 v=DKIM1; k=rsa; p=fleiwflki.... 这样。


如果是自己搭建的bind，直接把这段塞进域名的hosts文件就行。如果使用的是第三方解析，就去后台添加一条TXT记录，记录名是mail._domainkey，记录值是将两段引号内的字符串拼接起来即可，如我的就是：

v=DKIM1; k=rsa;p=MIGfMA0GCSqGSIb3DPENNNNNNNNNNCBiQKBgQCy9JV3FnXjLjsRJs/N0fy1C233333IV7t3f7fWpv/lo4NsoPEtG693hTgApkhuLl9KeV233333DMTagtXN898lXenKFEIS4COi7X/RjbGuOoApg4qS23333333TfXsrjN3xVC78E9T/HrS6pJN5fX+1s+1s+1s+1s+1s+1sIDAQAB



设置SPF记录。这个记录规定了可以用这个域发邮件的主机。在自己的邮件域名  上各添加一条TXT记录，记录名为@，值为v=spf1 mx ~all即可允许所有IP使用此域。如果你邮箱系统 有多个域名 来发送邮件。 都分别要添加的
设置DMARC记录。这个记录指出他们的地址被 SPF 和/或 DKIM/或别的方法保护。在自己的邮件域名上各添加一条TXT记录，记录名为_dmarc，值为v=DMARC1; p=none   如果你邮箱系统 有多个域名 来发送邮件。 都分别要添加的  


直接用这个容器获取证书方便快捷 https://github.com/tomav/docker-mailserver/wiki/Configure-SSL

mkdir -p /home/ubuntu/docker/letsencrypt/log 
mkdir -p /home/ubuntu/docker/letsencrypt/etc/letsencrypt
cd /home/ubuntu/docker/letsencrypt

docker run --rm -ti -v $PWD/log/:/var/log/letsencrypt/ -v $PWD/etc/:/etc/letsencrypt/ -p 443:443 deliverous/certbot certonly --standalone -d mail.nb03.com






###############下面这步骤可以不需要。  用上面容器快速获取证书#####################################
Ubuntu 下 安装  letsencrypt证书获取工具

apt-get update
 apt-get install software-properties-common
 add-apt-repository ppa:certbot/certbot
 apt-get update
 apt-get install certbot 

 
 确保将mail.nb03.com解析到了服务器IP,然后执行：

certbot certonly --standalone -d mail.nb03.com


因为上面的docker-compose.yml中已经把/etc/letsencrypt映射到了容器中所以到这里就完成了证书的工作。

输入crontab -e打开定时任务设置面板，然后按i进入编辑模式，粘贴进这段代码即可每周一凌晨5点0分给证书续期：

0 5 * * 1 /usr/bin/certbot renew --quiet

########################################################################


然后就可以 docker-compose up -d      了




启动容器后运行：
docker exec mail openssl s_client -connect 0.0.0.0:587 -starttls smtp -CApath /etc/letsencrypt/


和

docker exec mail openssl s_client -connect 0.0.0.0:993 -starttls imap -CApath /etc/letsencrypt/

看到这个说明成功了：
Verify return code: 0 (ok)




用户名是完整Email地址
IMAP和SMTP服务器都填 mail-server.example.com
IMAP 端口 143，STARTTLS，普通密码验证
SMTP 端口 587，STARTTLS，普通密码验证
