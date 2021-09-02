script {
    use 0x64a619c162d7c3bbc7f6029b375fd2d0::Market;
    // use 0x1::Market;
    use 0x1::Debug;
    use 0x1::Genesis;
    // use 0x1::Timestamp;
    // use 0x1::NFT;

    fun main(sender: signer) {
        
        Genesis::initialize_for_unit_tests();
        // Timestamp::update_global_time(&sender, 1629987337000);

        // NFT::initialize(&s2);
        // Market::initialize(&sender);

        
        // let now = Timestamp::now_seconds();
        // Debug::print(&now);
        
        
        Market::init(&sender);
        Market::put_on(&sender, b"test goods", 1, 10, 2, b"http://baidu.com", b"http://baidu.com", b"desc desc", true, 1630243014000, 50, b"qq@qq.com");
        Market::pull_off(&sender, 1);
        // Market::put_on(&sender, b"test goods2", 1, 10, 2, b"http://baidu.com", b"http://baidu.com", b"desc desc", true, 1630243014000, 50, b"qq@qq.com");
        let s = 1u8;
        Debug::print(&s);
    }
}