# cyberrare

## 部署合约
### 1.打开节点命令终端
```
./starcoin --connect  /data/stc/node/dev/starcoin.ipc  -o json console

// starcoin -n dev console  开发时可启动本地开发节点

```
### 2.账户导入/导出私钥
```
account export <address>

account import -i <priv>
```
### 3.给测试地址发测试币
```
dev get_coin -v 10000 0xee9227f1b5922ba4e1cefcb1b6e3638f  // 仅dev网络可以执行get_coin
```
### 4.编译/部署合约
```

// 确定部署地址

// 修改合约, 将`src/modules/market.move`中的所有`0xee9227f1b5922ba4e1cefcb1b6e3638f`替换为部署目标地址

dev compile src/modules/market.move  // 复制合约编译输出信息备用，等会会清屏
dev deploy -b -s 0xee9227f1b5922ba4e1cefcb1b6e3638f <file>  // 为两个文件，前后执行两次
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

### 8.查nft信息
```
state get resource 0x015f1607c973b0b7a0e4ecd9fa1c8169  0x1::NFTGallery::NFTGallery<0xee9227f1b5922ba4e1cefcb1b6e3638f::Market::GoodsNFTInfo,0xee9227f1b5922ba4e1cefcb1b6e3638f::Market::GoodsNFTBody>

// 命令第一个地址为所有人，后面的地址是合约地址
// nft在所有人地址空间中
// nft售卖中时，所有人是合约
```

## 9.升级NFT合约
```
dev compile src/modules/market.move
dev deploy -b -s 0xee9227f1b5922ba4e1cefcb1b6e3638f <path>/Market.mv
dev deploy -b -s 0xee9227f1b5922ba4e1cefcb1b6e3638f <path>/MarketScript.mv
account execute-function -b -s 0xee9227f1b5922ba4e1cefcb1b6e3638f --function 0xee9227f1b5922ba4e1cefcb1b6e3638f::MarketScript::upgrade 
// 上架数据保存在用户空间，命令前面地址是商品创建人地址，后面地址是合约名的组成部分
```