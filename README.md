
### 1.启动节点
```

// starcoin cli可用稳定版本1.9.1
./starcoin -n dev console  启动本地开发节点
./starcoin --connect  /data/stc/mainnet/main/starcoin.ipc  -o json console
```
### 2.编译合约
```
将`src/modules/market.move`中的所有`0x1e0c830eF929e530DDcfA8d79f758d09`替换为0x2d32bee4f260694a0b3f1143c64a505a官方合约部署地址

dev compile src/modules/market.move  // 编译合约

获得两个编译后的字节码文件
```
### 3.命令行部署代码
```
dev deploy -b -s 0x2d32bee4f260694a0b3f1143c64a505a <file>  // 直接部署，为两个文件，前后执行两次
```

### 4.网页部署代码（命令行不行就用这种方式，反之忽略)
```
生成编译字节码
dev package --hex 编译返回的字节码文件路径/Market.mv
dev package --hex 编译返回的字节码文件径/MarketScript.mv

https://starmask-test-dapp.starcoin.org/
1.连接钱包，确保钱包账号是要部署到的地址，及有可用STC余额
2.将HEX复制到Contract blob hex文本框中
3.点击部署
```
### 5.初始化Market
```
account execute-function -b -s 合约地址 --function 合约地址::MarketScript::init_market_v2 --arg 获取手续费的地址

account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::init_market_v2 --arg 0x2d32bee4f260694a0b3f1143c64a505a
```

### 6.初始化Staking
```
account execute-function -b -s 合约地址 --function 合约地址::MarketScript::init_staking_v2

account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::init_staking_v2
```

### 7.管理合作商
```
account execute-function -s 合约地址 --function 合约地址::MarketScript::create_partner_v2 --arg 合作商发布钱包地址 --arg 合作商类型
account execute-function -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::create_partner_v2 --arg 0x2d32bee4f260694a0b3f1143c64a505a --arg 0u64

account execute-function -s 合约账号 --function 合约账号::MarketScript::remove_partner_v2 --arg 需要删除的合作商钱包地址
account execute-function -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::remove_partner_v2 --arg 0x2d32bee4f260694a0b3f1143c64a505a
```
### 8.查看合约状态
```
state get resource 合约地址 合约地址::Market::MarketV2

state get resource 0x2d32bee4f260694a0b3f1143c64a505a 0x2d32bee4f260694a0b3f1143c64a505a::Market::MarketV2

https://stcscan.io/barnard/address/合约地址
```
