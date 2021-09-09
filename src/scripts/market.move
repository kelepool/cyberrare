script {
    use 0xee9227f1b5922ba4e1cefcb1b6e3638f::MarketScript;
    use 0x1::Debug;

    fun main(sender: signer) {
        MarketScript::put_on(sender, b"test goods 2", 1, 10, 5, b"http://baidu.com", b"http://baidu.com", b"desc desc", true, 1631001873, 9, b"qq@qq.com");
        let s = 1u8;
        Debug::print(&s);
        
    }
}