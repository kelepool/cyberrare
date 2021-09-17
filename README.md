# cyberrare

## 部署合约
### 1.启动本地开发节点
```
starcoin -n dev console
```
### 2.导入测试地址
```
account import -i 0xf6e1497eab98ee3fc24b971c3e3d11e6e6ad1435557b412937cdfdbeee52d779
```
### 3.给测试地址发测试币
```
dev get_coin -v 10000 0xee9227f1b5922ba4e1cefcb1b6e3638f
```
### 4.编译/部署合约
```
dev compile src/modules/market.move
dev deploy -b -s 0xee9227f1b5922ba4e1cefcb1b6e3638f <file>
```

    <file> 为编译返回的目标文件路径
### 5.初始化Market
```
account execute-function -b -s 0xee9227f1b5922ba4e1cefcb1b6e3638f --function 0xee9227f1b5922ba4e1cefcb1b6e3638f::MarketScript::init_market --arg 0xee9227f1b5922ba4e1cefcb1b6e3638f
```
### 6.查看合约状态
```
state get resource 0xee9227f1b5922ba4e1cefcb1b6e3638f 0xee9227f1b5922ba4e1cefcb1b6e3638f::Market::Market
```
### 7.查看指定地址上架数据
```
state get resource 0xee9227f1b5922ba4e1cefcb1b6e3638f 0xee9227f1b5922ba4e1cefcb1b6e3638f::Market::GoodsBasket
```

## 升级NFT合约
```
dev compile src/modules/market.move
dev deploy -b -s 0xee9227f1b5922ba4e1cefcb1b6e3638f <path>/Market.mv
dev deploy -b -s 0xee9227f1b5922ba4e1cefcb1b6e3638f <path>/MarketScript.mv
account execute-function -b -s 0xee9227f1b5922ba4e1cefcb1b6e3638f --function 0xee9227f1b5922ba4e1cefcb1b6e3638f::MarketScript::upgrade 
```