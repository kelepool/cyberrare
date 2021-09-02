# cyberrare

## 部署合约
### 1.启动本地开发节点
```
starcoin -n dev console
```
### 2.导入测试地址
```
account import -i 0x1d2b2c34eef7d047ca0a53b3e75938c8dc7722bc505fa475c7e29a12c58cebe0
```
### 3.给测试地址发测试币
```
dev get_coin -v 10000 0x01e562444828aeb8ac7eb0c060e6f274
```
### 4.编译/部署合约
```
dev compile src/modules/market.move
dev deploy -b -s 0x01e562444828aeb8ac7eb0c060e6f274 <file>
```

    <file> 为编译返回的目标文件路径
### 5.初始化Market
```
account execute-function -b -s 0x01e562444828aeb8ac7eb0c060e6f274 --function 0x01e562444828aeb8ac7eb0c060e6f274::MarketScript::init_market --arg 0x01e562444828aeb8ac7eb0c060e6f274
```
### 6.查看合约状态
```
state get resource 0x01e562444828aeb8ac7eb0c060e6f274 0x01e562444828aeb8ac7eb0c060e6f274::Market::Market
```
### 7.查看指定地址上架数据
```
state get resource 0x01e562444828aeb8ac7eb0c060e6f274 0x01e562444828aeb8ac7eb0c060e6f274::Market::GoodsBasket
```