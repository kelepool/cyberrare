script {
    use 0x01e562444828aeb8ac7eb0c060e6f274::MarketScript;
    use 0x1::Debug;

    fun main(sender: signer) {
        MarketScript::put_on(sender, b"test goods 2", 1, 10, 2, b"http://baidu.com", b"http://baidu.com", b"desc desc", true, 1631001873, 50, b"qq@qq.com");
        let s = 1u8;
        Debug::print(&s);
    }
}