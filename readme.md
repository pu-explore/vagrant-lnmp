# 环境

- nginx version: nginx/1.18.0 (Ubuntu)

- mysql Ver 8.0.28-0ubuntu0.20.04.3 for Linux on x86_64 (Ubuntu)

- Redis server v=5.0.7 (Ubuntu)

- PHP 7.4.3 (包含php-swoole扩展) (Ubuntu)

- composer


# 克隆

```shell
git clone https://github.com/pu-explore/vagrant-lnmp.git
```

# 配置软件源：`sources`

> 配置软件源，可防止因网络问题无法使用

```yaml
# Lnmp.yaml
sources: "http://mirrors.163.com"
ip: "192.168.10.10"
memory: 2048
```

> 国内软件源地址

- 网易：http://mirrors.163.com
- 阿里：http://mirrors.aliyun.com
- 清华：https://mirrors.tuna.tsinghua.edu.cn
- 中科大：https://mirrors.ustc.edu.cn

### 多站点时可配置IP默认站点：`default`

```yaml
# Lnmp.yaml
sites:
    - map: laravel.box
      to: /home/vagrant/code/laravel/public
    - map: lumen.box
      to: /home/vagrant/code/lumen/public
      default: true
```

> 配置默认站点，可实现局域网内通过IP:8000直接访问对应的站点，而无需设置域名
