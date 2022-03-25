## 合约
```
仓库地址：https://github.com/winlin/klstaking
分支：release
pr：https://github.com/winlin/klstaking/pull/13
```

### 1.启动节点
```
./starcoin -n dev console  启动本地开发节点
./starcoin --connect  /data/stc/mainnet/main/starcoin.ipc  -o json console

./starcoin --connect ws://main.seed.starcoin.org:9870 console 启动主网节点
./starcoin --connect ws://barnard.seed.starcoin.org:9870 console 启动测试网节点
```
### 2.编译合约
```
将`src/modules/market.move`中的所有`0x1e0c830eF929e530DDcfA8d79f758d09`替换为部署地址

dev compile src/modules/market.move  // 编译合约

获得两个编译后的字节码文件
```
### 3.命令行部署代码
```
dev deploy -b -s 0x1e0c830eF929e530DDcfA8d79f758d09 <file>  // 直接部署，为两个文件，前后执行两次
```

### 4.在线部署代码
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

account execute-function -b -s 0x1e0c830eF929e530DDcfA8d79f758d09 --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::init_market_v2 --arg 0x1e0c830eF929e530DDcfA8d79f758d09
```

### 6.管理合作商
```
account execute-function -s 合约地址 --function 合约地址::MarketScript::create_partner_v2 --arg 合作商发布钱包地址 --arg 合作商类型
account execute-function -s 0x1e0c830eF929e530DDcfA8d79f758d09 --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::create_partner_v2 --arg 0x1e0c830eF929e530DDcfA8d79f758d09 --arg 0u64

account execute-function -s 合约账号 --function 合约账号::MarketScript::remove_partner_v2 --arg 需要删除的合作商钱包地址
account execute-function -s 0x1e0c830eF929e530DDcfA8d79f758d09 --function 0x1e0c830eF929e530DDcfA8d79f758d09::MarketScript::remove_partner_v2 --arg 0x1e0c830eF929e530DDcfA8d79f758d09
```
### 7.查看合约状态
```
state get resource 合约地址 合约地址::Market::MarketV2

state get resource 0x1e0c830eF929e530DDcfA8d79f758d09 0x1e0c830eF929e530DDcfA8d79f758d09::Market::MarketV2

https://stcscan.io/barnard/address/合约地址
```
