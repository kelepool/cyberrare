script {
use 0x1::Block;
use 0x1::Debug;
fun main() {
  Debug::print(&Block::get_current_block_number());
}
}