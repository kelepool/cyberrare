address 0xee9227f1b5922ba4e1cefcb1b6e3638f {
// address 0x1 {
module Market {
    use 0x1::Signer;
    use 0x1::NFT::{Self, NFT, Metadata, MintCapability, UpdateCapability};
    use 0x1::NFTGallery;
    // use 0x1::CoreAddresses;
    use 0x1::Account;
    use 0x1::Timestamp;
    // use 0x1::NFTGallery;
    use 0x1::Token::{Self, Token};
    use 0x1::STC::STC;
    use 0x1::Event;
    use 0x1::Errors;
    use 0x1::Vector;
    use 0x1::Option::{Self, Option};

    const MARKET_ADDRESS: address = @0xee9227f1b5922ba4e1cefcb1b6e3638f;
    // const MARKET_ADDRESS: address = @0x1;

    //The market is closed
    const MARKET_LOCKED: u64 = 300;
    //The product has expired
    const MARKET_ITEM_EXPIRED: u64 = 301;
    //Invalid product quantity
    const MARKET_INVALID_QUANTITY: u64 = 302;
    const MARKET_INVALID_PRICE: u64 = 303;
    const MARKET_INVALID_INDEX: u64 = 304;
    //The auction is not over
    const MARKET_NOT_OVER: u64 = 305;
    const MARKET_INVALID_NFT_ID: u64 = 305;

    const MARKET_FEE_RATE: u128 = 3;

    //Products maximum effective bid
    const ARG_MAX_BID: u64 = 50;

    struct Market has key, store{
        counter: u64,
        is_lock: bool,
        funds: Token<STC>,
        cashier: address,
        fee_rate: u128,
        put_on_events: Event::EventHandle<PutOnEvent>,
        pull_off_events: Event::EventHandle<PullOffEvent>,
        bid_events: Event::EventHandle<BidEvent>,
        settlement_events: Event::EventHandle<SettlementEvent>,
        nfts: vector<NFT<GoodsNFTInfo, GoodsNFTBody>>,
    }

    struct GoodsNFTBody has store{
        //quantity
        quantity: u64,
    }

    //NFT ext info
    struct GoodsNFTInfo has copy, store, drop{
        ///has In kind
        has_in_kind: bool,
        /// type
        type: u64,
        // resource url
        resource_url: vector<u8>,
        ///creator email
        mail: vector<u8>,
    }

    struct Goods has store, drop{
        id: u128,
        //creator
        creator: address,
        //amount of put on
        amount: u64,
        //Whether there is already NFT
        nft_id: u64,
        //base price
        base_price: u128,
        //min add price
        add_price: u128,
        //last price
        last_price: u128,
        //sell amount
        sell_amount: u64,
        //end time
        end_time: u64,
        original_goods_id: u128,
        nft_base_meta: Metadata,
        nft_type_meta: GoodsNFTInfo,
        bid_list: vector<BidData>,
    }

    struct BidData has copy, store, drop {
        buyer: address,
        goods_id: u128,
        price: u128,
        quantity: u64,
        bid_count: u64,
        bid_time: u64,
        total_coin: u128,
    }

    //put on event
    struct PutOnEvent has drop, store {
        goods_id: u128,
        //seller
        owner: address,
        //Whether there is already NFT
        nft_id: u64,
        //base price
        base_price: u128,
        //min add price
        add_price: u128,
        //total amount
        amount: u64,
        // puton time
        put_on_time: u64,
        //end time
        end_time: u64,
        original_goods_id: u128,
        nft_base_meta: Metadata,
        nft_type_meta: GoodsNFTInfo,
    }

    //pull off event
    struct PullOffEvent has drop, store {
        owner: address,
        goods_id: u128,
        nft_id: u64,
    }

    struct BidEvent has drop, store {
        bidder: address,
        goods_id: u128,
        price: u128,
        quantity: u64,
        bid_time: u64,
    }

    struct SettlementEvent has drop, store {
        seller: address,
        buyer: address,
        goods_id: u128,
        nft_id: u64,
        price: u128,
        quantity: u64,
        bid_time: u64,
        time: u64,
    }

    //goods basket
    struct GoodsBasket has key, store{
        items: vector<Goods>,
    }

    struct GoodsNFTCapability has key {
        mint_cap: MintCapability<GoodsNFTInfo>,
        update_cap: UpdateCapability<GoodsNFTInfo>,
    }

    fun empty_info(): GoodsNFTInfo {
        GoodsNFTInfo {
            has_in_kind: false,
            type: 0,
            resource_url: Vector::empty(),
            mail: Vector::empty(),
        }
    }
    
    public fun init(sender: &signer, cashier: address) {        
        let _addr = check_market_owner(sender);
        
        NFT::register<GoodsNFTInfo, GoodsNFTInfo>(sender, empty_info(), NFT::empty_meta());
        let mint_cap = NFT::remove_mint_capability<GoodsNFTInfo>(sender);
        let update_cap = NFT::remove_update_capability<GoodsNFTInfo>(sender);
        move_to(sender, GoodsNFTCapability{mint_cap, update_cap});
        
        move_to<Market>(sender, Market{
            counter: 0,
            is_lock: false,
            funds: Token::zero<STC>(),
            cashier: cashier,
            fee_rate: MARKET_FEE_RATE,
            put_on_events: Event::new_event_handle<PutOnEvent>(sender),
            pull_off_events: Event::new_event_handle<PullOffEvent>(sender),
            bid_events: Event::new_event_handle<BidEvent>(sender),
            settlement_events: Event::new_event_handle<SettlementEvent>(sender),
            nfts: Vector::empty<NFT<GoodsNFTInfo, GoodsNFTBody>>(),
        });
    }

    fun mint_nft(creator: address, receiver: address, quantity: u64, base_meta: Metadata, type_meta: GoodsNFTInfo): u64 acquires GoodsNFTCapability {
        let cap = borrow_global_mut<GoodsNFTCapability>(MARKET_ADDRESS);
        let tm = copy type_meta;
        let md = copy base_meta;
        let nft = NFT::mint_with_cap<GoodsNFTInfo, GoodsNFTBody, GoodsNFTInfo>(creator, &mut cap.mint_cap, md, tm, GoodsNFTBody{quantity});
        let id = NFT::get_id(&nft);
        NFTGallery::deposit_to(receiver, nft);
        id
    }

    public fun has_basket(owner: address): bool {
        exists<GoodsBasket>(owner)
    }

    fun add_basket(sender: &signer) {
        let sender_addr = Signer::address_of(sender);
        if (!has_basket(sender_addr)) {
            let basket = GoodsBasket {
                items: Vector::empty<Goods>(),
            };
            move_to(sender, basket);
        }
    }

    public fun put_on_nft(sender: &signer, nft_id: u64, base_price: u128, add_price: u128, end_time: u64, mail: vector<u8>, original_goods_id: u128) acquires Market, GoodsNFTCapability, GoodsBasket {
        let op_nft = NFTGallery::withdraw<GoodsNFTInfo, GoodsNFTBody>(sender, nft_id);
        assert(Option::is_some(&op_nft), Errors::invalid_argument(MARKET_INVALID_NFT_ID));

        let nft = Option::destroy_some(op_nft);
        let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
        assert(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));
        // add goods count
        market_info.counter = market_info.counter + 1;
        // create goods
        let nft_info = NFT::get_info<GoodsNFTInfo, GoodsNFTBody>(&nft);
        let (nft_id, _, base_meta, type_meta) = NFT::unpack_info<GoodsNFTInfo>(nft_info);
        type_meta.mail = mail;

        let bm = copy base_meta;
        let tm = copy type_meta;
        let cap = borrow_global_mut<GoodsNFTCapability>(MARKET_ADDRESS);
        let body = NFT::borrow_body_mut_with_cap<GoodsNFTInfo, GoodsNFTBody>(&mut cap.update_cap, &mut nft);
        let amount = body.quantity;
        let owner = Signer::address_of(sender);
        let id = (market_info.counter as u128);
        let goods = Goods{
            id: id,
            creator: owner,
            amount: amount,
            nft_id: nft_id,
            base_price: base_price,
            add_price: add_price,
            last_price: base_price,
            sell_amount: 0,
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: base_meta,
            nft_type_meta: type_meta,
            bid_list: Vector::empty<BidData>(),
        };
        // add basket
        add_basket(sender);
        save_goods(owner, goods);
        // deposit nft to market
        // NFTGallery::deposit_to<GoodsNFTInfo, GoodsNFTBody>(MARKET_ADDRESS, nft);
        deposit_nft(&mut market_info.nfts, nft);
        // do emit event
        Event::emit_event(&mut market_info.put_on_events, PutOnEvent{
            goods_id: id,
            //seller
            owner: owner,
            nft_id: nft_id,
            //base price
            base_price: base_price,
            //min add price
            add_price: add_price,
            //total amount
            amount: amount,
            // puton time
            put_on_time: Timestamp::now_seconds(),
            //end time
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: bm,
            nft_type_meta: tm,
        });
    }

    public fun put_on(sender: &signer, title: vector<u8>, type: u64, base_price: u128, add_price: u128, image: vector<u8>, resource_url: vector<u8>, desc: vector<u8>, has_in_kind: bool, end_time: u64, amount: u64, mail: vector<u8>, original_goods_id: u128) acquires Market, GoodsBasket {
        // save counter
        let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
        assert(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        market_info.counter = market_info.counter + 1;
        let meta = NFT::new_meta_with_image(title, image, desc);
        let type_meta = GoodsNFTInfo{has_in_kind, type, resource_url, mail};
        let m2 = copy meta;
        let tm2 = copy type_meta;
        // create goods
        let owner = Signer::address_of(sender);
        let id = (market_info.counter as u128);
        let goods = Goods{
            id: id,
            creator: owner,
            amount: amount,
            nft_id: 0,
            base_price: base_price,
            add_price: add_price,
            last_price: base_price,
            sell_amount: 0,
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: meta,
            nft_type_meta: type_meta,
            bid_list: Vector::empty<BidData>(),
        };
        // add basket
        add_basket(sender);
        save_goods(owner, goods);
        // do emit event
        Event::emit_event(&mut market_info.put_on_events, PutOnEvent{
            goods_id: id,
            //seller
            owner: owner,
            nft_id: 0,
            //base price
            base_price: base_price,
            //min add price
            add_price: add_price,
            //total amount
            amount: amount,
            // puton time
            put_on_time: Timestamp::now_seconds(),
            //end time
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: m2,
            nft_type_meta: tm2,
        });
    }

    public fun find_index_by_id(v: &vector<Goods>, goods_id: u128): Option<u64>{
        let len = Vector::length(v);
        if (len == 0) {
            return Option::none()
        };
        let index = len - 1;
        loop {
            let goods = Vector::borrow(v, index);
            if (goods.id == goods_id) {
                return Option::some(index)
            };
            if (index == 0) {
                return Option::none()
            };
            index = index - 1;
        }
    }

    public fun find_nft_index_by_id(c: &vector<NFT<GoodsNFTInfo, GoodsNFTBody>>, id: u64): Option<u64> {
        let len = Vector::length(c);
        if (len == 0) {
            return Option::none()
        };
        let idx = len - 1;
        loop {
            let nft = Vector::borrow(c, idx);
            if (NFT::get_id(nft) == id) {
                return Option::some(idx)
            };
            if (idx == 0) {
                return Option::none()
            };
            idx = idx - 1;
        }
    }

    public fun find_bid_index(v: &vector<BidData>, goods_id: u128, buyer: address): Option<u64>{
        let len = Vector::length(v);
        if (len == 0) {
            return Option::none()
        };
        let index = len - 1;
        loop {
            let bid = Vector::borrow(v, index);
            if (bid.goods_id == goods_id && bid.buyer == buyer) {
                return Option::some(index)
            };
            if (index == 0) {
                return Option::none()
            };
            index = index - 1;
        }
    }

    fun save_goods(owner: address, goods: Goods) acquires GoodsBasket{
        let basket = borrow_global_mut<GoodsBasket>(owner);
        Vector::push_back(&mut basket.items, goods);
    }

    fun get_goods(owner: address, goods_id: u128): Option<Goods> acquires GoodsBasket {
        let basket = borrow_global_mut<GoodsBasket>(owner);
        let index = find_index_by_id(&basket.items, goods_id);
        if (Option::is_some(&index)) {
            let i = Option::extract(&mut index);
            let g = Vector::remove<Goods>(&mut basket.items, i);
            Option::some(g)
        }else {
            Option::none()
        }
    }

    fun borrow_goods(list: &mut vector<Goods>, goods_id: u128): &mut Goods {
        let index = find_index_by_id(list, goods_id);
        assert(Option::is_some(&index), Errors::invalid_argument(MARKET_INVALID_INDEX));
        let i = Option::extract(&mut index);
        Vector::borrow_mut<Goods>(list, i)
    }

    fun save_bid(list: &mut vector<BidData>, bid_data: BidData) {
        Vector::push_back(list, bid_data);
    }

    fun borrow_bid_data(list: &mut vector<BidData>, index: u64): &mut BidData {
        Vector::borrow_mut<BidData>(list, index)
    }

    fun deposit_nft(list: &mut vector<NFT<GoodsNFTInfo, GoodsNFTBody>>, nft: NFT<GoodsNFTInfo, GoodsNFTBody>) {
        Vector::push_back(list, nft);
    }

    fun withdraw_nft(list: &mut vector<NFT<GoodsNFTInfo, GoodsNFTBody>>, nft_id: u64): Option<NFT<GoodsNFTInfo, GoodsNFTBody>> {
        let len = Vector::length(list);
        let nft = if (len == 0) {
            Option::none()
        }else {
            let idx = find_nft_index_by_id(list, nft_id);
            if (Option::is_some(&idx)) {
                let i = Option::extract(&mut idx);
                let nft = Vector::remove<NFT<GoodsNFTInfo, GoodsNFTBody>>(list, i);
                Option::some(nft)
            }else {
                Option::none()
            }
        };
        nft
    }

    fun market_pull_off(owner: address, goods_id: u128) acquires Market, GoodsBasket{
        let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
        let g = get_goods(owner, goods_id);
        if(Option::is_some(&g)){
            let goods = Option::extract(&mut g);
            if(Vector::length(&goods.bid_list) == 0){
                let Goods{ id, creator, amount: _, nft_id, base_price: _, add_price: _, last_price: _, sell_amount: _, end_time: _, nft_base_meta: _, nft_type_meta: _, bid_list: _, original_goods_id: _ } = goods;
                if(nft_id > 0 ) {
                    let op_nft = withdraw_nft(&mut market_info.nfts, nft_id);
                    let nft = Option::destroy_some(op_nft);
                    // deposit nft to creator
                    NFTGallery::deposit_to<GoodsNFTInfo, GoodsNFTBody>(creator, nft);
                };
                // do emit event
                Event::emit_event(&mut market_info.pull_off_events, PullOffEvent{
                    goods_id: id,
                    owner: owner,
                    nft_id: nft_id,
                });
            } else {
                save_goods(owner, goods);
            }
        }
    }

    public fun pull_off(sender: &signer, goods_id: u128) acquires Market, GoodsBasket {
        let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
        assert(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        let owner = Signer::address_of(sender);
        market_pull_off(owner, goods_id);
    }

    fun check_price(base_price: u128, add_price: u128, price: u128): bool {
        if((price - base_price) % add_price == 0 && price >= (base_price + add_price)){
            true
        }else{
            false
        }
    }

    fun sort_bid(list: &mut vector<BidData>) {
        let i = 0u64;
        let j = 0u64;
        let len = Vector::length(list);
        while(i < len){
            while(j+1 < len - i){
                let a = Vector::borrow(list, j);
                let b = Vector::borrow(list, j+1);
                if(a.price < b.price) {
                    Vector::swap(list, j, j+1);
                } else if(a.price == b.price){
                    if(a.bid_time > b.bid_time){
                        Vector::swap(list, j, j+1);
                    };
                };
                j = j + 1;
            };
            i = i + 1;
        };
    }

    fun refunds_by_bid(list: &mut vector<BidData>, limit: u64, pool: &mut Token<STC>) {
        let count = 0u64;
        let valid_count = 0u64;
        let index = 0u64;
        let len = Vector::length(list);
        while(index < len) {
            let a = Vector::borrow(list, index);
            count = count + a.quantity;
            if(count > limit) {
                break
            } else if (count == limit) {
                valid_count = count;
                break
            };
            valid_count = count;
            index = index + 1;
        };
        if(count > limit && index < len) {
            let b = Vector::borrow_mut(list, index);
            b.quantity = limit - valid_count;
            let amount = (b.quantity as u128) * b.price;
            //refunds
            let tokens = Token::withdraw<STC>(pool, b.total_coin - amount);
            b.total_coin = amount;
            Account::deposit(b.buyer, tokens);
        };
        index = index + 1;
        while(len - 1 >= index ){
            let b = Vector::remove(list, len - 1);
            let tokens = Token::withdraw<STC>(pool, b.total_coin);
            Account::deposit(b.buyer, tokens);
            len = len - 1;
        };
    }

    fun get_bid_price(list: &vector<BidData>, base_price: u128, quantity: u64): u128 {
        let price = base_price;
        let len = Vector::length(list);
        let i = len;
        let count = 0u64;
        while(i > 0){
            let a = Vector::borrow(list, i - 1);
            count = count + a.quantity;
            price = a.price;
            if(count >= quantity) {
                break
            };
            i = i - 1;
        };
        price
    }

    public fun bid(sender: &signer, seller: address, goods_id: u128, price: u128, quantity: u64) acquires Market, GoodsBasket {
        let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
        assert(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        let sender_addr = Signer::address_of(sender);
        let basket = borrow_global_mut<GoodsBasket>(seller);
        let goods = borrow_goods(&mut basket.items, goods_id);
        if(goods.nft_id > 0) {
            assert(quantity == goods.amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));
        };
        let now = Timestamp::now_seconds();
        assert(now < goods.end_time, Errors::invalid_state(MARKET_ITEM_EXPIRED));
        assert(quantity > 0 && quantity <= goods.amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));
        let last_price = if(quantity <= goods.amount - goods.sell_amount) {
            goods.base_price
        } else {
            get_bid_price(&goods.bid_list, goods.base_price, quantity)
        };
        assert(check_price(last_price, goods.add_price, price), Errors::invalid_argument(MARKET_INVALID_PRICE));
        //accept nft
        NFTGallery::accept<GoodsNFTInfo, GoodsNFTBody>(sender);
        //save state
        let new_amount = price * (quantity as u128);
        //deduction
        let tokens = Account::withdraw<STC>(sender, new_amount);
        Token::deposit(&mut market_info.funds, tokens);
        save_bid(&mut goods.bid_list, BidData{
            buyer: sender_addr,
            goods_id,
            price,
            quantity,
            bid_count: 1,
            bid_time: now,
            total_coin: new_amount,
        });
        if(price > goods.last_price) {
            goods.last_price = price;
        };
        if(goods.sell_amount + quantity <= goods.amount) {
            goods.sell_amount = goods.sell_amount + quantity;
        }else{
            goods.sell_amount = goods.amount;
        };
        sort_bid(&mut goods.bid_list);
        let limit = goods.amount;
        refunds_by_bid(&mut goods.bid_list, limit, &mut market_info.funds);
        // do emit event
        Event::emit_event(&mut market_info.bid_events, BidEvent{
            bidder: sender_addr,
            goods_id: goods_id,
            price: price,
            quantity: quantity,
            bid_time: Timestamp::now_seconds(),
        });
    }

    public fun set_lock(sender: &signer, is_lock: bool) acquires Market {
        check_market_owner(sender);
        let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
        market_info.is_lock = is_lock;
    }

    public fun settlement(sender: &signer, seller: address, goods_id: u128) acquires Market, GoodsBasket, GoodsNFTCapability {
        check_market_owner(sender);
        let basket = borrow_global_mut<GoodsBasket>(seller);
        let g = borrow_goods(&mut basket.items, goods_id);
        let now = Timestamp::now_seconds();
        assert(now >= g.end_time, Errors::invalid_state(MARKET_NOT_OVER));
        let len = Vector::length(&g.bid_list);
        if(len > 0) {
            let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
            let og = get_goods(seller, goods_id);
            let goods = Option::extract(&mut og);
            let i = 0u64;
            while(i < len) {
                let nft_id = goods.nft_id;
                let bm = *&goods.nft_base_meta;
                let tm = *&goods.nft_type_meta;
                let bid_data = borrow_bid_data(&mut goods.bid_list, i);
                //mint nft
                if(nft_id > 0) {
                    let op_nft = withdraw_nft(&mut market_info.nfts, nft_id);
                    let nft = Option::destroy_some(op_nft);
                    // deposit nft to buyer
                    NFTGallery::deposit_to<GoodsNFTInfo, GoodsNFTBody>(bid_data.buyer, nft);
                } else {
                    nft_id = mint_nft(seller, bid_data.buyer, bid_data.quantity, bm, tm);
                };
                //handling charge
                let fee = (bid_data.total_coin * MARKET_FEE_RATE) / 100;
                if(fee > 0u128) {
                    let fee_tokens = Token::withdraw<STC>(&mut market_info.funds, fee);
                    Account::deposit(market_info.cashier, fee_tokens);
                    //to pay
                    let pay_tokens = Token::withdraw<STC>(&mut market_info.funds, bid_data.total_coin - fee);
                    Account::deposit(seller, pay_tokens);
                } else {
                    //to pay
                    let pay_tokens = Token::withdraw<STC>(&mut market_info.funds, bid_data.total_coin);
                    Account::deposit(seller, pay_tokens);
                };
                Event::emit_event(&mut market_info.settlement_events, SettlementEvent {
                    seller: seller,
                    buyer: bid_data.buyer,
                    goods_id: goods_id,
                    nft_id: nft_id,
                    price: bid_data.price,
                    quantity: bid_data.quantity,
                    bid_time: bid_data.bid_time,
                    time: now,
                });
                i = i + 1;
            }
        } else {
            market_pull_off(seller, goods_id);
        };
    }

    fun check_market_owner(sender: &signer): address {
        let addr = Signer::address_of(sender);
        assert(addr == MARKET_ADDRESS, Errors::invalid_argument(1000));
        addr
    }
}

module MarketScript {
    use 0xee9227f1b5922ba4e1cefcb1b6e3638f::Market;

    //account execute-function -b -s 0xee9227f1b5922ba4e1cefcb1b6e3638f --function 0xee9227f1b5922ba4e1cefcb1b6e3638f::MarketScript::init_market --arg 0xee9227f1b5922ba4e1cefcb1b6e3638f
    public(script) fun init_market(account: signer, cashier: address) {
        Market::init(&account, cashier);
    }

    //account execute-function -b --function 0xee9227f1b5922ba4e1cefcb1b6e3638f::MarketScript::put_on --arg <...>
    public(script) fun put_on(account: signer, title: vector<u8>, type: u64, base_price: u128, add_price: u128, image: vector<u8>, resource_url: vector<u8>, desc: vector<u8>, has_in_kind: bool, end_time: u64, amount: u64, mail: vector<u8>, original_goods_id: u128) {
        Market::put_on(&account, title, type, base_price, add_price, image, resource_url, desc, has_in_kind, end_time, amount, mail, original_goods_id);
    }

    //account execute-function -b --function 0xee9227f1b5922ba4e1cefcb1b6e3638f::MarketScript::put_on_nft --arg <...>
    public(script) fun put_on_nft(sender: signer, nft_id: u64, base_price: u128, add_price: u128, end_time: u64, mail: vector<u8>, original_goods_id: u128) {
        Market::put_on_nft(&sender, nft_id, base_price, add_price, end_time, mail, original_goods_id);
    }

    //account execute-function -b --function 0xee9227f1b5922ba4e1cefcb1b6e3638f::MarketScript::pull_off --arg <...>
    public(script) fun pull_off(account: signer, goods_id: u128) {
        Market::pull_off(&account, goods_id);
    }

    // account execute-function -b --function 0xee9227f1b5922ba4e1cefcb1b6e3638f::MarketScript::bid --arg 0xee9227f1b5922ba4e1cefcb1b6e3638f 1u128 12u128 1u64
    // "gas_used": "344104"
    public(script) fun bid(account: signer, seller: address, goods_id: u128, price: u128, quantity: u64) {
        Market::bid(&account, seller, goods_id, price, quantity);
    }

    // account execute-function -b -s 0xee9227f1b5922ba4e1cefcb1b6e3638f --function 0xee9227f1b5922ba4e1cefcb1b6e3638f::MarketScript::settlement --arg 0xee9227f1b5922ba4e1cefcb1b6e3638f 1u128
    public(script) fun settlement(sender: signer, seller: address, goods_id: u128) {
        Market::settlement(&sender, seller, goods_id);
    }

    // account execute-function -b -s 0xee9227f1b5922ba4e1cefcb1b6e3638f --function 0xee9227f1b5922ba4e1cefcb1b6e3638f::MarketScript::set_lock --arg false
    public(script) fun set_lock(sender: signer, is_lock: bool) {
        Market::set_lock(&sender, is_lock);
    }

    // public(script) fun test_put_on(sender: signer, end_time: u64) {
    //     Market::put_on(&sender, b"test goods", 1, 10, 2, b"http://baidu.com", b"http://baidu.com", b"desc desc", true, end_time, 50, b"qq@qq.com",0);
    // }

    // public(script) fun test_put_on_nft(sender: signer, nft_id: u64, end_time: u64) {
    //     Market::put_on_nft(&sender, nft_id, 12, 2, end_time, b"qq@qq.com");
    // }
}
}