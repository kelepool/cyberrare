address 0x2d32bee4f260694a0b3f1143c64a505a {
// address 0x1 {
module Market {
    use StarcoinFramework::Signer;
    use StarcoinFramework::NFT::{Self, NFT, Metadata, MintCapability,BurnCapability, UpdateCapability};
    use StarcoinFramework::NFTGallery;
    // use 0x1::CoreAddresses;
    use StarcoinFramework::Account;
    use StarcoinFramework::Timestamp;
    // use 0x1::NFTGallery;
    use StarcoinFramework::Token::{Self, Token};
    use StarcoinFramework::STC::STC;
    use StarcoinFramework::Event;
    use StarcoinFramework::Errors;
    use StarcoinFramework::Vector;
    use StarcoinFramework::Option::{Self, Option};
    use StarcoinFramework::Signature;
    use StarcoinFramework::BCS;
    //use StarcoinFramework::Hash;

    const MARKET_ADDRESS: address = @0x2d32bee4f260694a0b3f1143c64a505a;
    const SIGNER_ADDRESS: vector<u8> = x"617f25cafa887a348503ac7a09a681e244c727dc0ef739eda7372e44f84577a9";

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
        
        // NFT::register<GoodsNFTInfo, GoodsNFTInfo>(sender, empty_info(), NFT::empty_meta());
        NFT::register_v2<GoodsNFTInfo>(sender, NFT::empty_meta());
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

    public fun upgrade(sender: &signer) acquires GoodsNFTCapability {
        let _addr = check_market_owner(sender);
        let cap = borrow_global_mut<GoodsNFTCapability>(_addr);
        NFT::upgrade_nft_type_info_from_v1_to_v2<GoodsNFTInfo, GoodsNFTInfo>(sender, &mut cap.mint_cap);
        let _nft_info = NFT::remove_compat_info<GoodsNFTInfo, GoodsNFTInfo>(&mut cap.mint_cap);
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
        assert!(Option::is_some(&op_nft), Errors::invalid_argument(MARKET_INVALID_NFT_ID));

        let nft = Option::destroy_some(op_nft);
        let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
        assert!(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));
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
        assert!(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

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
        assert!(Option::is_some(&index), Errors::invalid_argument(MARKET_INVALID_INDEX));
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
            let len = Vector::length(&goods.bid_list);
            if(len>0){
                refunds_by_bid(&mut goods.bid_list, 0, &mut market_info.funds);
            };

            let Goods{ id, creator, amount: _, nft_id, base_price: _, add_price: _, last_price: _, sell_amount: _, end_time: _, nft_base_meta: _, nft_type_meta: _, bid_list: _, original_goods_id: _ } = goods;
            if(nft_id > 0 ) {
                let op_nft = withdraw_nft(&mut market_info.nfts, nft_id);
                let nft = Option::destroy_some(op_nft);
                // deposit nft to creator
                NFTGallery::deposit_to<GoodsNFTInfo, GoodsNFTBody>(creator, nft);
            };

            Event::emit_event(&mut market_info.pull_off_events, PullOffEvent{
                goods_id: id,
                owner: owner,
                nft_id: nft_id,
            });
        }
    }

    public fun pull_off(sender: &signer, goods_id: u128) acquires Market, GoodsBasket {
        let market_info = borrow_global_mut<Market>(MARKET_ADDRESS);
        assert!(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

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
            j = 0;
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
        assert!(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        let sender_addr = Signer::address_of(sender);
        let basket = borrow_global_mut<GoodsBasket>(seller);
        let goods = borrow_goods(&mut basket.items, goods_id);
        if(goods.nft_id > 0) {
            assert!(quantity == goods.amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));
        };
        let now = Timestamp::now_seconds();
        assert!(now < goods.end_time, Errors::invalid_state(MARKET_ITEM_EXPIRED));
        assert!(quantity > 0 && quantity <= goods.amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));
        let last_price = if(quantity <= goods.amount - goods.sell_amount) {
            goods.base_price
        } else {
            get_bid_price(&goods.bid_list, goods.base_price, quantity)
        };
        assert!(check_price(last_price, goods.add_price, price), Errors::invalid_argument(MARKET_INVALID_PRICE));
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
            bid_time: now,
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
        assert!(now >= g.end_time, Errors::invalid_state(MARKET_NOT_OVER));
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
        assert!(addr == MARKET_ADDRESS, Errors::invalid_argument(1000));
        addr
    }





    // ==================================================================(new version)==================================================================================

    //The action is deprecated
    const DEPRECATED_METHOD:u64 = 100;

    const MARKET_INVALID_NFT_AMOUNT: u64 = 306;
    const MARKET_INVALID_PACKAGES:u64 = 307;
    const MARKET_INVALID_SELL_WAY:u64 = 308;
    const MARKET_INVALID_BUYER:u64 = 309;
    const STAKE_NFT_ERROR_COUNT:u64 = 310;
    const STAKE_NFT_ERROR_INDEX:u64 = 311;
    const STAKE_ERROR_NFT_KIND:u64 = 312;
    const STAKE_ERROR_NFT_PACKAGES:u64 = 313;
    const STAKE_NFT_ERROR_AMOUNT:u64 = 314;
    const STAKE_NFT_ERROR_NONCE:u64 = 315;
    const STAKE_NFT_ERROR_SIGNATURE:u64 = 316;
    const STAKE_NFT_ERROR_POWER:u64 = 317;
    const STAKE_NFT_ERROR_SIGNER:u64 = 318;
    const STAKE_NFT_ERROR_KIND:u64 = 319;
    const MARKET_ERROR_EXTENSIONS:u64 = 320;

    // sell way = buy now
    const DICT_TYPE_SELL_WAY_BUY_NOW: u64 = 1801;

    // sell way = bid
    const DICT_TYPE_SELL_WAY_BID: u64 = 1802;

    // sell way = buy now + bid
    const DICT_TYPE_SELL_WAY_BUY_NOW_AND_BID: u64 = 1803;

    // sell way = dutch
    const DICT_TYPE_SELL_WAY_DUTCH_BID: u64 = 1804;

    // gtype = goods
    const DICT_TYPE_CATEGORY_GOODS: u64 = 1901;

    // gtype = boxes
    const DICT_TYPE_CATEGORY_BOXES: u64 = 1902;

    // 2201 normal 10-100
    const DICT_TYPE_RARITY_NORMAL: u64 = 2201;

    // 2202 normal 50-100 Execllent 
    const DICT_TYPE_RARITY_EXECLLENT: u64 = 2202;

    // 2301 time liner damping
    const DICT_TYPE_DAMPING_TIME_LINER: u64 = 2301;

    // for test 
    const SYSTEM_ERROR_TEST:u64 = 999;

    // packages
    struct PackageV2 has copy, store, drop {
        id:u64,
        type:u64,
        preview:vector<u8>,
        resource:vector<u8>,
    }

    // item value
    struct ExtenstionV2 has copy, store, drop {
        // item
        item:u64,
        // value
        value:u128
    }

    // nft global id
    struct IdentityV2 has key, store{
        id:u64
    }

    // nft store house
    struct StorehouseV2 has key,store{
        nfts: vector<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>>,
    }

    // trash
    struct TrashV2 has key,store{
        nfts: vector<NFT<GoodsNFTInfo, GoodsNFTBody>>,
    }

    // events
    struct EventV2<phantom T:drop + store> has key,store{
        events: Event::EventHandle<T>,
    }

    // marketplace
    struct MarketV2 has key, store{
        counter: u64,
        is_lock: bool,
        funds: Token<STC>,
        cashier: address,
        fee_rate: u128,
        // ================================ new ========================
        // extensions
        extensions:vector<ExtenstionV2>
    }

    // not copyable
    struct GoodsNFTBodyV2 has store{
        // quantity
        quantity: u64,
    }

    // NFT ext info
    struct GoodsNFTInfoV2 has copy, store, drop {
        // has In kind
        has_in_kind: bool,
        // type
        type: u64,
        // resource url
        resource_url: vector<u8>,
        // rarity 
        rarity: u64,
        // power
        power:u64,
        // total staking period time(seconds)
        period:u64,
        // damping
        damping:u64,
        // running
        running:u64,
        // kind
        kind:u64,
        // ================================ new ========================
        // gtype (1901:goods, 1902:mystery box)
        gtype:u64,
        // the mystery box or goods always false, but its true when box opened
        is_open: bool,
        // is official
        is_official:bool,
        // main nft id
        main_nft_id:u64,
        // tags
        tags:vector<u8>,
        // boxes
        packages:vector<PackageV2>,
        // extensions
        extensions:vector<ExtenstionV2>
    }

    // goods info
    struct GoodsV2 has store, drop{
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
        nft_type_meta: GoodsNFTInfoV2,
        bid_list: vector<BidDataV2>,
        // ================================ new ========================
        // sell way (1801:fixed price, 1802:bid, 1803:fixed price+bid, 1804:dutch auction)
        sell_way:u64,
        // duration time
        duration:u64,
        // start time
        start_time: u64,
        // fixed_price
        fixed_price:u128,
        // dutch auction start price
        dutch_start_price:u128,
        // dutch auction end price
        dutch_end_price:u128,
        // original_amount
        original_amount:u64,
        // extensions
        extensions:vector<ExtenstionV2>
    }

    struct BidDataV2 has copy, store, drop {
        buyer: address,
        goods_id: u128,
        price: u128,
        quantity: u64,
        bid_count: u64,
        bid_time: u64,
        total_coin: u128,
    }

    //goods basket
    struct GoodsBasketV2 has key, store{
        items: vector<GoodsV2>,
    }

    struct GoodsNFTNewCapabilityV2 has key {
        mint_cap: MintCapability<GoodsNFTInfoV2>,
        burn_cap: BurnCapability<GoodsNFTInfoV2>,
        update_cap: UpdateCapability<GoodsNFTInfoV2>,
        old_burn_cap: BurnCapability<GoodsNFTInfo>,
    }

    struct UpgradeNFTEventV2 has drop,store{
        goods_id:u128,
        main_nft_id:u64,// new goods 1000+, old one is the same of old_nft_id
        old_version:u64,
        old_nft_id:u64,
        new_version:u64,
        new_nft_id:u64,
    }

    // open box event
    struct OpenBoxEventV2 has drop,store{
        parent_main_nft_id:u64,
        main_nft_id:u64,
        new_nft_id:u64,
        new_version:u64,
        preview_url:vector<u8>,
        //======================== new ======================
        rarity: u64,
        power:u64,
        period:u64,
        damping:u64,
        running:u64,
        kind:u64,
        unopen:u64,
        time:u64,
        is_open:bool,
        is_official:bool,
        title:vector<u8>,
        resource_url:vector<u8>
    }

    struct BuyNowEventV2 has drop, store {
        seller: address,
        buyer: address,
        goods_id: u128,
        nft_id: u64,
        price: u128,
        quantity: u64,
        time: u64,
        //======================== new ======================
        // nft main id
        main_nft_id:u64,
        // sell way (1801:fixed price, 1802:bid, 1803:fixed price+bid, 1804:dutch auction)
        sell_way:u64,
        // remain amount
        remain_amount:u64,
        // gtype (1901:goods, 1902:mystery box)
        gtype:u64,
        // rarity
        rarity: u64,
        // power
        power:u64,
        // period
        period:u64,
        // damping
        damping:u64,
        // running
        running:u64,
        // kind
        kind:u64,
        // is_open
        is_open:bool,
        // is official
        is_official:bool,
        // amount,
        amount:u64,
        // sell amount
        sell_amount:u64,
        // original amount
        original_amount:u64
    }

    //put on event
    struct PutOnEventV2 has drop, store {
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
        nft_type_meta: GoodsNFTInfoV2,
        //================================================ new ======================
        // sell way (1801:fixed price, 1802:bid, 1803:fixed price+bid, 1804:dutch auction)
        sell_way:u64,
        // duration time
        duration:u64,
        // start time
        start_time: u64,
        // fixed_price
        fixed_price:u128,
        // dutch auction start price
        dutch_start_price:u128,
        // dutch auction end price
        dutch_end_price:u128,
        // original_amount
        original_amount:u64,
        // extensions
        extensions:vector<ExtenstionV2>

    }

    //pull off event
    struct PullOffEventV2 has drop, store {
        owner: address,
        goods_id: u128,
        nft_id: u64,
    }

    struct BidEventV2 has drop, store {
        bidder: address,
        goods_id: u128,
        price: u128,
        quantity: u64,
        bid_time: u64,
    }

    struct SettlementEventV2 has drop, store {
        seller: address,
        buyer: address,
        goods_id: u128,
        nft_id: u64,
        price: u128,
        quantity: u64,
        bid_time: u64,
        time: u64,
        //======================== new ======================
        // nft main id
        main_nft_id:u64,
        // sell way (1801:fixed price, 1802:bid, 1803:fixed price+bid, 1804:dutch auction)
        sell_way:u64,
        // gtype (1901:goods, 1902:mystery box)
        gtype:u64,
        // rarity
        rarity: u64,
        // power
        power:u64,
        // period
        period:u64,
        // damping
        damping:u64,
        // running
        running:u64,
        // kind
        kind:u64,
        // is open
        is_open:bool,
        // is official
        is_official:bool,
        // amount,
        amount:u64,
        // sell amount
        sell_amount:u64,
        // original amount
        original_amount:u64
    }

    // our partner's address
    struct PartnerV2 has key,store {
        members:vector<PartnerItemV2>
    }

    // our partner's address
    struct PartnerItemV2 has drop,store {
        type:u64,
        partner:address
    }

    // partner event
    struct PartnerEventV2 has drop, store {
        owner:address,
        type:u64,
        partner:address,
        method:u64,
    }

    // pool
    struct StakingPoolV2 has key, store{
        // total nft count
        counter: u64,
        // staking limit count
        limit:u64,
        // total jackpot
        jackpot: Token<STC>,
        // total power
        power: u64,
        // share per power
        share: u128,
        // timestamp
        time:u64,
        // boxes
        packages:vector<vector<u8>>,
        // fee rate
        fee_rate:u128
    }

    // nft staking house
    struct StakingNftV2 has key,store{
        nfts: vector<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>>,
    }

    // nft staking user
    struct StakingUserV2 has key,store{
        // user total power
        power: u64,
        // user debt
        debt: u128,
        // user staking nft ids
        items: vector<StakingUserItemV2>,
        // verify unchain signature
        nonce:u64,
        // total reward
        reward: Token<STC>,
    }

    // nft staking user item
    struct StakingUserItemV2 has key,store,drop{
        nft_id:u64,
        time:u64,
    }

    // deposit nft event
    struct StakingDepositEventV2 has drop, store {
        owner: address,
        nft_id: u64,
        time:u64,
        nft_base_meta: Metadata,
        nft_type_meta: GoodsNFTInfoV2,
        pool_power:u64,
        pool_amount:u128,
    }

    // withdraw nft event
    struct StakingWithdrawEventV2 has drop, store {
        owner: address,
        nft_id: u64,
        time:u64,
        nft_base_meta: Metadata,
        nft_type_meta: GoodsNFTInfoV2,
        pool_power:u64,
        pool_amount:u128,
        start_time:u64,
    }

    // reward event
    struct StakingRewardEventV2 has drop, store {
        owner: address,
        amount: u128,
        nonce: u64,
        time:u64,
        signature:vector<u8>,
        pool_power:u64,
        pool_amount:u128,
    }

    // recharge event
    struct StakingRechargeEventV2 has drop, store {
        owner: address,
        amount: u128,
        time:u64,
        pool_power:u64,
        pool_amount:u128,
    }

    // exchange event
    struct StakingExchangeEventV2 has drop, store {
        owner: address,
        old_nft_id:u64,
        old_nft_base_meta: Metadata,
        old_nft_type_meta: GoodsNFTInfoV2,
        new_nft_id:u64,
        new_nft_base_meta: Metadata,
        new_nft_type_meta: GoodsNFTInfoV2,
        time:u64,
    }

    fun lshift_u128(x: u128, n: u8): u128 {
        (x << n)
    }

    public fun find_user_nft_index_by_id_v2(v: &vector<StakingUserItemV2>, nft_id: u64): Option<u64>{
        let len = Vector::length(v);
        if (len == 0) {
            return Option::none()
        };
        let index = len - 1;
        loop {
            let nft = Vector::borrow(v, index);
            if (nft.nft_id == nft_id) {
                return Option::some(index)
            };
            if (index == 0) {
                return Option::none()
            };
            index = index - 1;
        }
    }

    public fun staking_deposit_v2(sender: &signer, nft_id: u64) acquires StakingPoolV2,StakingNftV2,EventV2,StakingUserV2 {

        let owner = Signer::address_of(sender);
        let new_nft = NFTGallery::withdraw<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender, nft_id);    
        assert!(Option::is_some(&new_nft), Errors::invalid_argument(MARKET_INVALID_NFT_ID));    

        let nft = Option::destroy_some(new_nft);
        let nft_info = NFT::get_info<GoodsNFTInfoV2, GoodsNFTBodyV2>(&nft);
        let (nft_id, _, base_meta, type_meta) = NFT::unpack_info<GoodsNFTInfoV2>(nft_info);
        assert!(type_meta.power>0 && type_meta.kind==1, Errors::invalid_argument(STAKE_NFT_ERROR_KIND));

        // create user info
        let bm = copy base_meta;
        let tm = copy type_meta;
        let stake_item = StakingUserItemV2{
            nft_id:nft_id,
            time:Timestamp::now_seconds()
        };

        // change pool info
        let pool_info = borrow_global_mut<StakingPoolV2>(MARKET_ADDRESS);
        pool_info.power = pool_info.power + tm.power;
        pool_info.counter = pool_info.counter + 1;
        
        if (!exists<StakingUserV2>(owner)) {
            let stake_items = Vector::empty<StakingUserItemV2>();
            Vector::push_back(&mut stake_items, stake_item);
            let user_info = StakingUserV2 {
                // user total power
                power: tm.power,
                // user debt
                debt: 0,
                // user staking nft ids
                items: stake_items,
                // verify unchain signature
                nonce:0,
                // reward
                reward:Token::zero<STC>()
            };
            move_to(sender, user_info);
        }else{
            let user_info = borrow_global_mut<StakingUserV2>(owner);
            assert!(Vector::length(&user_info.items) < pool_info.limit, Errors::invalid_argument(STAKE_NFT_ERROR_COUNT));

            user_info.power = user_info.power + tm.power;
            Vector::push_back(&mut user_info.items, stake_item);
        };

        // deposit nft to stake
        let stake_house = borrow_global_mut<StakingNftV2>(MARKET_ADDRESS);
        deposit_nft_v2(&mut stake_house.nfts, nft);

        // do emit event
        let stake_deposit_event = borrow_global_mut<EventV2<StakingDepositEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut stake_deposit_event.events, StakingDepositEventV2{
            owner: owner,
            nft_id: nft_id,
            time: Timestamp::now_seconds(),
            nft_base_meta: bm,
            nft_type_meta: tm,
            pool_power:pool_info.power,
            pool_amount:Token::value(&pool_info.jackpot)
        });
    }

    public fun staking_withdraw_v2(sender: &signer, nft_id: u64) acquires StakingPoolV2,StakingNftV2,EventV2,StakingUserV2,GoodsNFTNewCapabilityV2 {

        // get user info
        let owner = Signer::address_of(sender);
        let user_info = borrow_global_mut<StakingUserV2>(owner);
        assert!(Vector::length(&user_info.items) > 0, Errors::invalid_argument(STAKE_NFT_ERROR_COUNT));

        // get nft item
        let nft_index = find_user_nft_index_by_id_v2(&user_info.items, nft_id);
        assert!(Option::is_some(&nft_index), Errors::invalid_argument(STAKE_NFT_ERROR_INDEX));
        let item_index = Option::extract(&mut nft_index);
        let user_item = Vector::remove<StakingUserItemV2>(&mut user_info.items, item_index);

        // get nft info
        let stake_house = borrow_global_mut<StakingNftV2>(MARKET_ADDRESS);
        let stake_nft = withdraw_nft_v2(&mut stake_house.nfts, nft_id);
        let my_nft = Option::destroy_some(stake_nft);

        //assert!(nft_id==0,Errors::invalid_argument(SYSTEM_ERROR_TEST));

        // change stake time
        let my_cap = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);
        let my_nft_info = NFT::get_info<GoodsNFTInfoV2, GoodsNFTBodyV2>(&my_nft);
        let (_my_nft_id, _, my_base_meta, my_type_meta) = NFT::unpack_info<GoodsNFTInfoV2>(my_nft_info);
        my_type_meta.running = my_type_meta.running + (Timestamp::now_seconds() - user_item.time);
        NFT::update_meta_with_cap(&mut my_cap.update_cap, &mut my_nft,copy my_base_meta,copy my_type_meta);

        // change pool,user info
        let pool_info = borrow_global_mut<StakingPoolV2>(MARKET_ADDRESS);
        pool_info.power = pool_info.power - my_type_meta.power;
        pool_info.counter = pool_info.counter - 1;
        user_info.power = user_info.power - my_type_meta.power;

        // deposit nft to user
        let bm = copy my_base_meta;
        let tm = copy my_type_meta;
        NFTGallery::deposit_to<GoodsNFTInfoV2, GoodsNFTBodyV2>(owner, my_nft);

        // do emit event
        let stake_withdraw_event = borrow_global_mut<EventV2<StakingWithdrawEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut stake_withdraw_event.events, StakingWithdrawEventV2{
            owner: owner,
            nft_id: nft_id,
            time: Timestamp::now_seconds(),
            nft_base_meta: bm,
            nft_type_meta: tm,
            pool_power:pool_info.power,
            pool_amount:Token::value(&pool_info.jackpot),
            start_time:user_item.time,
        });
    }

    public fun staking_reward_v2(sender: &signer, amount: u128, nonce:u64, signature:vector<u8>) acquires StakingPoolV2,EventV2,StakingUserV2 {

        let owner = Signer::address_of(sender);
        assert!(amount>0, Errors::invalid_argument(STAKE_NFT_ERROR_AMOUNT));
        assert!(nonce>0, Errors::invalid_argument(STAKE_NFT_ERROR_NONCE));
        assert!(Vector::length(&signature)>0, Errors::invalid_argument(STAKE_NFT_ERROR_SIGNATURE));

        let user_info = borrow_global_mut<StakingUserV2>(owner);
        assert!(nonce > user_info.nonce, Errors::invalid_argument(STAKE_NFT_ERROR_NONCE));

        let message = Vector::empty<u8>();
        let owner_bytes = BCS::to_bytes(&owner);
        let amount_bytes = BCS::to_bytes(&amount);
        let nonce_bytes = BCS::to_bytes(&nonce);
        Vector::append(&mut message,copy owner_bytes);
        Vector::append(&mut message,copy amount_bytes);
        Vector::append(&mut message,copy nonce_bytes);

        let check = Signature::ed25519_verify(copy signature, SIGNER_ADDRESS, copy message);
        assert!(check==true, Errors::invalid_argument(STAKE_NFT_ERROR_SIGNER));

        //assert!(amount==0,Errors::invalid_argument(SYSTEM_ERROR_TEST));

        // withdraw stc
        let pool_info = borrow_global_mut<StakingPoolV2>(MARKET_ADDRESS);
        let tokens = Token::withdraw<STC>(&mut pool_info.jackpot, amount);
        user_info.nonce = nonce;
        Account::deposit(owner, tokens);

        // do emit event
        let stake_reward_event = borrow_global_mut<EventV2<StakingRewardEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut stake_reward_event.events, StakingRewardEventV2{
            owner:  owner,
            amount: amount,
            nonce: nonce,
            time: Timestamp::now_seconds(),
            signature:signature,
            pool_power:pool_info.power,
            pool_amount:Token::value(&pool_info.jackpot),
        });
    }

    public fun staking_recharge_v2(sender: &signer, amount: u128) acquires EventV2,StakingPoolV2{

        // deposit stc
        let owner = Signer::address_of(sender);
        let pool_info = borrow_global_mut<StakingPoolV2>(MARKET_ADDRESS);
        let tokens = Account::withdraw<STC>(sender, amount);
        Token::deposit(&mut pool_info.jackpot, tokens);

        // do emit event
        let exchange_nft_event = borrow_global_mut<EventV2<StakingRechargeEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut exchange_nft_event.events, StakingRechargeEventV2{
            owner: owner,
            amount: amount,
            time: Timestamp::now_seconds(),
            pool_power:pool_info.power,
            pool_amount:Token::value(&pool_info.jackpot),
        });
    }

    public fun staking_exchange_v2(sender: &signer, nft_id: u64) acquires GoodsNFTNewCapabilityV2,EventV2,StakingPoolV2,IdentityV2 {

        // check old nft
        let owner = Signer::address_of(sender);
        let get_old_nft = NFTGallery::withdraw<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender, nft_id);
        assert!(Option::is_some(&get_old_nft), Errors::invalid_argument(MARKET_INVALID_NFT_ID));  

        // get old nft
        let old_nft = Option::destroy_some(get_old_nft);
        let old_nft_info = NFT::get_info<GoodsNFTInfoV2, GoodsNFTBodyV2>(&old_nft);
        let (_old_nft_id, _, old_base_meta, old_type_meta) = NFT::unpack_info<GoodsNFTInfoV2>(old_nft_info);
        let nft_power = *&old_type_meta.power;
        let nft_kind = *&old_type_meta.kind;
        let old_nft_base_meta = copy old_base_meta;
        let old_nft_type_meta = copy old_type_meta;
        assert!(nft_kind==0 && nft_power>0, Errors::invalid_argument(STAKE_ERROR_NFT_KIND));

        // check packages list
        let now = Timestamp::now_milliseconds();
        let pool_info = borrow_global_mut<StakingPoolV2>(MARKET_ADDRESS);
        let count = Vector::length(&pool_info.packages);
        assert!(count>0, Errors::invalid_argument(STAKE_ERROR_NFT_PACKAGES));

        // get random image
        let image = Vector::remove<vector<u8>>(&mut pool_info.packages, (now % count));
        let identity = borrow_global_mut<IdentityV2>(MARKET_ADDRESS);
        identity.id = identity.id +1;

        //assert!(nft_id==0,Errors::invalid_argument(SYSTEM_ERROR_TEST));

        // create new nft
        let new_cap = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);
        let new_base_meta = NFT::new_meta_with_image(NFT::meta_name(&old_base_meta), copy image, NFT::meta_description(&old_base_meta));
        let new_type_meta = GoodsNFTInfoV2{has_in_kind:*&old_type_meta.has_in_kind, type:*&old_type_meta.type, resource_url:image, rarity:*&old_type_meta.rarity, power:*&old_type_meta.power, period:*&old_type_meta.period,damping:*&old_type_meta.damping,running:*&old_type_meta.running,kind:1, gtype:DICT_TYPE_CATEGORY_GOODS, is_open:*&old_type_meta.is_open,is_official:*&old_type_meta.is_official, main_nft_id:identity.id,tags:*&old_type_meta.tags, packages:*&old_type_meta.packages ,extensions:*&old_type_meta.extensions};
        let new_nft = NFT::mint_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2, GoodsNFTInfoV2>(MARKET_ADDRESS, &mut new_cap.mint_cap, copy new_base_meta, copy new_type_meta, GoodsNFTBodyV2{quantity:1});
        let new_nft_id = NFT::get_id(&new_nft);

        // burn old nft
        let GoodsNFTBodyV2{ quantity:_ } = NFT::burn_with_cap(&mut new_cap.burn_cap,old_nft);

        // deposit new nft to user
        NFTGallery::deposit_to<GoodsNFTInfoV2, GoodsNFTBodyV2>(owner, new_nft);

        // do emit event
        let exchange_nft_event = borrow_global_mut<EventV2<StakingExchangeEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut exchange_nft_event.events, StakingExchangeEventV2{
            owner: owner,
            old_nft_id: nft_id,
            old_nft_base_meta: old_nft_base_meta,
            old_nft_type_meta: old_nft_type_meta,
            new_nft_id:new_nft_id,
            new_nft_base_meta: new_base_meta,
            new_nft_type_meta: new_type_meta,
            time:Timestamp::now_seconds(),
        });

    }

    // add exchange packages
    public fun staking_add_exchange_v2(sender: &signer,packages:vector<vector<u8>>) acquires PartnerV2,StakingPoolV2{

        let owner = Signer::address_of(sender);
        assert!(check_partner_exist(owner)==true,Errors::invalid_argument(1000));
        
        let i = 0u64;
        let len = Vector::length(&packages);
        let pool_info = borrow_global_mut<StakingPoolV2>(MARKET_ADDRESS);
        while(i < len){
            let package = *Vector::borrow(&packages,i);
            Vector::push_back(&mut pool_info.packages, package);
            i=i+1;
        };
    }

    // add exchange packages
    public fun staking_clean_exchange_v2(sender: &signer) acquires PartnerV2,StakingPoolV2{

        let owner = Signer::address_of(sender);
        assert!(check_partner_exist(owner)==true,Errors::invalid_argument(1000));
        
        let pool_info = borrow_global_mut<StakingPoolV2>(MARKET_ADDRESS);
        pool_info.packages = Vector::empty<vector<u8>>()
    }

    // get market extensions
    fun get_market_extensions(index:u64):u128 acquires MarketV2 {
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        let count = Vector::length(&market_info.extensions);
        assert!(index < count,Errors::invalid_argument(MARKET_ERROR_EXTENSIONS));
        let info = *Vector::borrow(&market_info.extensions,index);
        info.value
    }

    // set market extensions
    fun set_market_extensions(index:u64,value:u128,summation:bool) acquires MarketV2 {
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        let count = Vector::length(&market_info.extensions);
        assert!(index < count,Errors::invalid_argument(MARKET_ERROR_EXTENSIONS));
        let info = Vector::borrow_mut<ExtenstionV2>(&mut market_info.extensions,index);
        info.item = index;
        if(summation){
            info.value = info.value + value;
        }else{
            info.value = value;
        };
    }

    // init staking
    public fun init_staking_v2(sender: &signer) {       

        check_market_owner_v2(sender);

        // init StakingDepositEventV2 event
        move_to<EventV2<StakingDepositEventV2>>(sender,EventV2<StakingDepositEventV2>{
            events:Event::new_event_handle<StakingDepositEventV2>(sender),
        });

        // init StakingWithdrawEventV2 event
        move_to<EventV2<StakingWithdrawEventV2>>(sender,EventV2<StakingWithdrawEventV2>{
            events:Event::new_event_handle<StakingWithdrawEventV2>(sender),
        });

        // init StakingRewardEventV2 event
        move_to<EventV2<StakingRewardEventV2>>(sender,EventV2<StakingRewardEventV2>{
            events:Event::new_event_handle<StakingRewardEventV2>(sender),
        });

        // init StakingRechargeEventV2 event
        move_to<EventV2<StakingRechargeEventV2>>(sender,EventV2<StakingRechargeEventV2>{
            events:Event::new_event_handle<StakingRechargeEventV2>(sender),
        });

        // init StakingExchangeEventV2 event
        move_to<EventV2<StakingExchangeEventV2>>(sender,EventV2<StakingExchangeEventV2>{
            events:Event::new_event_handle<StakingExchangeEventV2>(sender),
        });

        // init pool
        let packages = Vector::empty<vector<u8>>();
        move_to<StakingPoolV2>(sender, StakingPoolV2{
            // total nft count
            counter: 0,
            // staking limit count
            limit: 6,
            // total jackpot
            jackpot: Token::zero<STC>(),
            // total power
            power: 0,
            // share per power
            share: 0,
            // timestamp
            time:0,
            // packages
            packages:packages,
            // fee rate
            fee_rate:10
        });

        // init staking store
        move_to<StakingNftV2>(sender,StakingNftV2{
            nfts:Vector::empty<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>>()
        });

        // init staking jackpot
        // let extensions = Vector::empty<ExtenstionV2>();
        // let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        // Vector::push_back(&mut extensions, ExtenstionV2{ item:0,value:0 });
        // market_info.extensions = extensions;
    }

    public fun create_test_data_v2(sender: &signer) acquires IdentityV2,GoodsNFTCapability,GoodsNFTNewCapabilityV2 {

        let sender_addr = Signer::address_of(sender);

        // create old nft
         NFTGallery::accept<GoodsNFTInfo, GoodsNFTBody>(sender);
        let old_cap = borrow_global_mut<GoodsNFTCapability>(MARKET_ADDRESS);
        let old_meta = NFT::new_meta_with_image(b"Cyberrare", b"https://www.cyberrare.io/v1.png", b"Cyberrare V1");
        let old_type_meta = GoodsNFTInfo{ has_in_kind:false , type:0u64, resource_url:b"", mail:b""};
        let old_nft = NFT::mint_with_cap<GoodsNFTInfo, GoodsNFTBody, GoodsNFTInfo>(sender_addr, &mut old_cap.mint_cap, old_meta, old_type_meta, GoodsNFTBody{quantity:1});
        NFTGallery::deposit_to(sender_addr, old_nft);

        // create new nft
        let identity = borrow_global_mut<IdentityV2>(MARKET_ADDRESS);
        identity.id = identity.id + 1;
         NFTGallery::accept<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender);
        let new_cap = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);
        let new_meta = NFT::new_meta_with_image(b"Cyberrare", b"https://www.cyberrare.io/v1.png", b"Cyberrare V2");
        let new_type_meta = GoodsNFTInfoV2{ has_in_kind:false , type:0u64, resource_url:b"", rarity:0, power:50, period:0 ,damping:0, running:0,kind:0,gtype:DICT_TYPE_CATEGORY_GOODS,is_open:false,is_official:false,main_nft_id:identity.id,tags:Vector::empty<u8>(),packages:Vector::empty<PackageV2>(),extensions:Vector::empty<ExtenstionV2>()};
        let new_nft = NFT::mint_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2, GoodsNFTInfoV2>(sender_addr, &mut new_cap.mint_cap, new_meta, new_type_meta, GoodsNFTBodyV2{quantity:1});
        NFTGallery::deposit_to(sender_addr, new_nft);

        // create staking nft
        identity.id = identity.id + 1;
        let new_cap2 = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);
        let new_meta2 = NFT::new_meta_with_image(b"Cyberrare", b"https://www.cyberrare.io/v2.png", b"Cyberrare V3");
        let new_type_meta2 = GoodsNFTInfoV2{ has_in_kind:false , type:0u64, resource_url:b"", rarity:0, power:75, period:0 ,damping:0, running:0,kind:1,gtype:DICT_TYPE_CATEGORY_GOODS,is_open:false,is_official:false,main_nft_id:identity.id,tags:Vector::empty<u8>(),packages:Vector::empty<PackageV2>(),extensions:Vector::empty<ExtenstionV2>()};
        let new_nft2 = NFT::mint_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2, GoodsNFTInfoV2>(sender_addr, &mut new_cap2.mint_cap, new_meta2, new_type_meta2, GoodsNFTBodyV2{quantity:1});
        NFTGallery::deposit_to(sender_addr, new_nft2);
    }

    fun get_packages_v2(packages: vector<vector<u8>>,package_types:vector<u64>):vector<PackageV2> {
        let len = Vector::length(&packages);
        let new_packages = Vector::empty<PackageV2>();
        let i = 0u64;
        while(i < len){
            let package = *Vector::borrow(&packages,i);
            let package_type = *Vector::borrow(&package_types,i);
            Vector::push_back<PackageV2>(&mut new_packages, PackageV2{id:(i+1), type:package_type, preview:Vector::empty<u8>(),resource: package });
            i=i+1;
        };
        new_packages
    }

    fun save_goods_v2(owner: address, goods: GoodsV2) acquires GoodsBasketV2{
        let basket = borrow_global_mut<GoodsBasketV2>(owner);
        Vector::push_back(&mut basket.items, goods);
    }

    fun add_basket_v2(sender: &signer) {
        let sender_addr = Signer::address_of(sender);
        if (!exists<GoodsBasketV2>(sender_addr)) {
            let basket = GoodsBasketV2 {
                items: Vector::empty<GoodsV2>(),
            };
            move_to(sender, basket);
        }
    }

    fun mint_nft_v2(creator: address, receiver: address, quantity: u64, base_meta: Metadata, type_meta: GoodsNFTInfoV2): u64 acquires GoodsNFTNewCapabilityV2 {
        let cap = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);
        let tm = copy type_meta;
        let md = copy base_meta;
        let nft = NFT::mint_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2, GoodsNFTInfoV2>(creator, &mut cap.mint_cap, md, tm, GoodsNFTBodyV2{quantity});
        let id = NFT::get_id(&nft);
        NFTGallery::deposit_to(receiver, nft);
        id
    }

    fun deposit_nft_v2(list: &mut vector<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>>, nft: NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>) {
        Vector::push_back(list, nft);
    }

    fun deposit_trush_v2(list: &mut vector<NFT<GoodsNFTInfo,GoodsNFTBody>>, nft: NFT<GoodsNFTInfo, GoodsNFTBody>){
        Vector::push_back(list, nft);
    }

    public fun find_index_by_id_v2(v: &vector<GoodsV2>, goods_id: u128): Option<u64>{
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

    fun borrow_goods_v2(list: &mut vector<GoodsV2>, goods_id: u128): &mut GoodsV2 {
        let index = find_index_by_id_v2(list, goods_id);
        assert!(Option::is_some(&index), Errors::invalid_argument(MARKET_INVALID_INDEX));
        let i = Option::extract(&mut index);
        Vector::borrow_mut<GoodsV2>(list, i)
    }

    fun get_bid_price_v2(list: &vector<BidDataV2>, base_price: u128, quantity: u64): u128 {
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

    fun save_bid_v2(list: &mut vector<BidDataV2>, bid_data: BidDataV2) {
        Vector::push_back(list, bid_data);
    }

    fun sort_bid_v2(list: &mut vector<BidDataV2>) {
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
            j = 0;
            i = i + 1;
        };
    }

    fun refunds_by_bid_v2(list: &mut vector<BidDataV2>, limit: u64, pool: &mut Token<STC>) {
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

    fun get_goods_v2(owner: address, goods_id: u128): Option<GoodsV2> acquires GoodsBasketV2 {
        let basket = borrow_global_mut<GoodsBasketV2>(owner);
        let index = find_index_by_id_v2(&basket.items, goods_id);
        if (Option::is_some(&index)) {
            let i = Option::extract(&mut index);
            let g = Vector::remove<GoodsV2>(&mut basket.items, i);
            Option::some(g)
        }else {
            Option::none()
        }
    }


    fun borrow_bid_data_v2(list: &mut vector<BidDataV2>, index: u64): &mut BidDataV2 {
        Vector::borrow_mut<BidDataV2>(list, index)
    }


    fun withdraw_nft_v2(list: &mut vector<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>>, nft_id: u64): Option<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>> {
        let len = Vector::length(list);
        let nft = if (len == 0) {
            Option::none()
        }else {
            let idx = find_nft_index_by_id_v2(list, nft_id);
            if (Option::is_some(&idx)) {
                let i = Option::extract(&mut idx);
                let nft = Vector::remove<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>>(list, i);
                Option::some(nft)
            }else {
                Option::none()
            }
        };
        nft
    }

    public fun find_nft_index_by_id_v2(c: &vector<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>>, id: u64): Option<u64> {
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

    fun market_pull_off_v2(owner: address, goods_id: u128) acquires EventV2,MarketV2,StorehouseV2, GoodsBasketV2{
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        let storehouse = borrow_global_mut<StorehouseV2>(MARKET_ADDRESS);
        let g = get_goods_v2(owner, goods_id);
        if(Option::is_some(&g)){
            let goods = Option::extract(&mut g);
            let len = Vector::length(&goods.bid_list);
            if(len>0){
                refunds_by_bid_v2(&mut goods.bid_list, 0, &mut market_info.funds);
            };

            let GoodsV2{ id, creator, amount: _, nft_id, base_price: _, add_price: _, last_price: _, sell_amount: _, end_time: _, nft_base_meta: _, nft_type_meta: _, bid_list: _, original_goods_id: _,sell_way:_,duration:_,start_time:_,fixed_price:_,dutch_start_price:_,dutch_end_price:_,extensions:_,original_amount:_ } = goods;
            if(nft_id > 0 ) {
                let op_nft = withdraw_nft_v2(&mut storehouse.nfts, nft_id);
                let nft = Option::destroy_some(op_nft);
                // deposit nft to creator
                NFTGallery::deposit_to<GoodsNFTInfoV2, GoodsNFTBodyV2>(creator, nft);
            };

            let pull_off_event = borrow_global_mut<EventV2<PullOffEventV2>>(MARKET_ADDRESS);
            Event::emit_event(&mut pull_off_event.events, PullOffEventV2{
                goods_id: id,
                owner: owner,
                nft_id: nft_id,
            });

        }
    }

    public fun pull_off_v2(sender: &signer, goods_id: u128) acquires EventV2,MarketV2,StorehouseV2, GoodsBasketV2 {
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        assert!(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        NFTGallery::accept<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender);
        
        let owner = Signer::address_of(sender);
        market_pull_off_v2(owner, goods_id);
    }

    fun put_on_nft_new_v2(sender: &signer, nft_id: u64, sell_way:u64, fixed_price:u128, tags:vector<u8>, base_price: u128, add_price: u128, end_time: u64, original_goods_id: u128) acquires MarketV2, GoodsNFTNewCapabilityV2, GoodsBasketV2,StorehouseV2,EventV2 {
        
        // get nft info
        let new_nft = NFTGallery::withdraw<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender, nft_id);    
        assert!(Option::is_some(&new_nft), Errors::invalid_argument(MARKET_INVALID_NFT_ID));    

        let nft = Option::destroy_some(new_nft);
        let cap = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);
        let nft_info = NFT::get_info<GoodsNFTInfoV2, GoodsNFTBodyV2>(&nft);
        let (nft_id, _, base_meta, type_meta) = NFT::unpack_info<GoodsNFTInfoV2>(nft_info);
        type_meta.tags = tags;
        NFT::update_meta_with_cap(&mut cap.update_cap, &mut nft,copy base_meta,copy type_meta);

        // add goods count        
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        market_info.counter = market_info.counter + 1;

        // create goods
        let bm = copy base_meta;
        let tm = copy type_meta;
        let body = NFT::borrow_body_mut_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2>(&mut cap.update_cap, &mut nft);
        let amount = if(type_meta.gtype==DICT_TYPE_CATEGORY_BOXES){
            Vector::length(&type_meta.packages)
        }else{
            body.quantity
        };
        let owner = Signer::address_of(sender);
        let id = (market_info.counter as u128);
        let goods = GoodsV2 {
            id: id,
            creator: owner,
            amount: 0,
            nft_id: nft_id,
            base_price: base_price,
            add_price: add_price,
            last_price: base_price,
            sell_amount: 0,
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: base_meta,
            nft_type_meta: type_meta,
            bid_list: Vector::empty<BidDataV2>(),

            // sell way (0:fixed price, 1:bid, 2:dutch auction)
            sell_way:sell_way,
            // duration time
            duration:0,
            // start time
            start_time: 0,
            // fixed_price
            fixed_price:fixed_price,
            // dutch auction start price
            dutch_start_price:0,
            // dutch auction end price
            dutch_end_price:0,
            // original_amount
            original_amount:amount,
            // extensions
            extensions:Vector::empty<ExtenstionV2>()
        };

        // add basket
        add_basket_v2(sender);
        save_goods_v2(owner, goods);

        // deposit nft to market
        let storehouse = borrow_global_mut<StorehouseV2>(MARKET_ADDRESS);
        deposit_nft_v2(&mut storehouse.nfts, nft);

        // do emit event
        let put_on_event = borrow_global_mut<EventV2<PutOnEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut put_on_event.events, PutOnEventV2{
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

            // sell way (0:fixed price, 1:bid, 2:dutch auction)
            sell_way:sell_way,
            // duration time
            duration:0,
            // start time
            start_time: 0,
            // fixed_price
            fixed_price:fixed_price,
            // dutch auction start price
            dutch_start_price:0,
            // dutch auction end price
            dutch_end_price:0,
            // original_amount
            original_amount:amount,
            // extensions
            extensions:Vector::empty<ExtenstionV2>()
        });
    }

    fun put_on_nft_old_v2(sender: &signer, nft_id: u64, sell_way:u64, fixed_price:u128, tags:vector<u8>, base_price: u128, add_price: u128, end_time: u64, original_goods_id: u128) acquires MarketV2, GoodsNFTNewCapabilityV2, GoodsBasketV2,StorehouseV2,EventV2,GoodsNFTCapability {

        // get old nft 
        let owner = Signer::address_of(sender);
        let get_old_nft = NFTGallery::withdraw<GoodsNFTInfo, GoodsNFTBody>(sender, nft_id);
        assert!(Option::is_some(&get_old_nft), Errors::invalid_argument(MARKET_INVALID_NFT_ID));  

        let old_cap = borrow_global_mut<GoodsNFTCapability>(MARKET_ADDRESS);
        let old_nft = Option::destroy_some(get_old_nft);
        let old_nft_info = NFT::get_info<GoodsNFTInfo, GoodsNFTBody>(&old_nft);
        let (_old_nft_id, _, old_base_meta, old_type_meta) = NFT::unpack_info<GoodsNFTInfo>(old_nft_info);
        let old_nft_body = NFT::borrow_body_mut_with_cap<GoodsNFTInfo, GoodsNFTBody>(&mut old_cap.update_cap, &mut old_nft);
        //let old_trush = borrow_global_mut<TrashV2>(MARKET_ADDRESS);
        
        // create new nft
        let new_amount = old_nft_body.quantity;
        let new_cap = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);
        let new_base_meta = copy old_base_meta;
        let new_type_meta = GoodsNFTInfoV2{has_in_kind:*&old_type_meta.has_in_kind, type:*&old_type_meta.type, resource_url:*&old_type_meta.resource_url, rarity:0, power:0, period:0,damping:0,running:0,kind:0, gtype:DICT_TYPE_CATEGORY_GOODS, is_open:false,is_official:false, main_nft_id:nft_id,tags, packages:Vector::empty<PackageV2>() ,extensions:Vector::empty<ExtenstionV2>()};
        let new_nft = NFT::mint_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2, GoodsNFTInfoV2>(owner, &mut new_cap.mint_cap, copy new_base_meta, copy new_type_meta, GoodsNFTBodyV2{quantity:new_amount});
        let new_nft_id = NFT::get_id(&new_nft);

        // burn old nft
        //deposit_trush_v2(&mut old_trush.nfts,old_nft);
        let GoodsNFTBody{ quantity:_ } = NFT::burn_with_cap(&mut new_cap.old_burn_cap,old_nft);

        // add goods count        
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        market_info.counter = market_info.counter + 1;

        // create goods
        let bm = copy new_base_meta;
        let tm = copy new_type_meta;
        //let body = NFT::borrow_body_mut_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2>(&mut new_cap.update_cap, &mut new_nft);
        
        let id = (market_info.counter as u128);
        let goods = GoodsV2 {
            id: id,
            creator: owner,
            amount: 0,
            nft_id: new_nft_id,
            base_price: base_price,
            add_price: add_price,
            last_price: base_price,
            sell_amount: 0,
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: new_base_meta,
            nft_type_meta: new_type_meta,
            bid_list: Vector::empty<BidDataV2>(),

            // sell way (0:fixed price, 1:bid, 2:dutch auction)
            sell_way:sell_way,
            // duration time
            duration:0,
            // start time
            start_time: 0,
            // fixed_price
            fixed_price:fixed_price,
            // dutch auction start price
            dutch_start_price:0,
            // dutch auction end price
            dutch_end_price:0,
            // original_amount
            original_amount:new_amount,
            // extensions
            extensions:Vector::empty<ExtenstionV2>()
        };

        // add basket
        add_basket_v2(sender);
        save_goods_v2(owner, goods);

        // deposit nft to market
        let storehouse = borrow_global_mut<StorehouseV2>(MARKET_ADDRESS);
        deposit_nft_v2(&mut storehouse.nfts, new_nft);

        let upgrade_nft_event = borrow_global_mut<EventV2<UpgradeNFTEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut upgrade_nft_event.events, UpgradeNFTEventV2{
            goods_id:id,
            main_nft_id:nft_id,
            old_version:1,
            old_nft_id:nft_id,
            new_version:2,
            new_nft_id:new_nft_id,
        });

        // do emit event
        let put_on_event = borrow_global_mut<EventV2<PutOnEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut put_on_event.events, PutOnEventV2{
            goods_id: id,
            //seller
            owner: owner,
            nft_id: new_nft_id,
            //base price
            base_price: base_price,
            //min add price
            add_price: add_price,
            //total amount
            amount: new_amount,
            // puton time
            put_on_time: Timestamp::now_seconds(),
            //end time
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: bm,
            nft_type_meta: tm,

            // sell way (0:fixed price, 1:bid, 2:dutch auction)
            sell_way:sell_way,
            // duration time
            duration:0,
            // start time
            start_time: 0,
            // fixed_price
            fixed_price:fixed_price,
            // dutch auction start price
            dutch_start_price:0,
            // dutch auction end price
            dutch_end_price:0,
            // original_amount
            original_amount:new_amount,
            // extensions
            extensions:Vector::empty<ExtenstionV2>()
        });
    }

    // cancel goods
    public fun cancel_goods_v1(sender: &signer,seller:address, goods_id: u128) acquires Market, GoodsBasket{

        check_market_owner_v2(sender);

        market_pull_off(seller, goods_id);
    }

    // cancel goods
    public fun cancel_goods_v2(sender: &signer,seller:address, goods_id: u128) acquires EventV2,MarketV2,StorehouseV2, GoodsBasketV2 {

        check_market_owner_v2(sender);

        market_pull_off_v2(seller, goods_id);
    }

    // sync market 
    public fun sync_market_v2(sender: &signer) acquires Market,MarketV2{

        check_market_owner_v2(sender);

        // sync market
        let old_market = borrow_global_mut<Market>(MARKET_ADDRESS);
        let new_market = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        new_market.cashier = old_market.cashier;
        new_market.fee_rate = old_market.fee_rate;

        let market_funds = Token::value(&old_market.funds);
        if(market_funds>0){
            let tokens = Token::withdraw<STC>(&mut old_market.funds, market_funds);
            Token::deposit(&mut new_market.funds, tokens); 
        }
    }

    public fun exchange_nft_v2(sender: &signer, nft_id: u64) acquires GoodsNFTNewCapabilityV2,EventV2,GoodsNFTCapability {

        // get old nft 
        let owner = Signer::address_of(sender);
        let get_old_nft = NFTGallery::withdraw<GoodsNFTInfo, GoodsNFTBody>(sender, nft_id);
        assert!(Option::is_some(&get_old_nft), Errors::invalid_argument(MARKET_INVALID_NFT_ID));  

        let old_cap = borrow_global_mut<GoodsNFTCapability>(MARKET_ADDRESS);
        let old_nft = Option::destroy_some(get_old_nft);
        let old_nft_info = NFT::get_info<GoodsNFTInfo, GoodsNFTBody>(&old_nft);
        let (_old_nft_id, _, old_base_meta, old_type_meta) = NFT::unpack_info<GoodsNFTInfo>(old_nft_info);
        let old_nft_body = NFT::borrow_body_mut_with_cap<GoodsNFTInfo, GoodsNFTBody>(&mut old_cap.update_cap, &mut old_nft);
        //let old_trush = borrow_global_mut<TrashV2>(MARKET_ADDRESS);
        
        // create new nft
        let new_amount = old_nft_body.quantity;
        let new_cap = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);
        let new_base_meta = copy old_base_meta;
        let new_type_meta = GoodsNFTInfoV2{has_in_kind:*&old_type_meta.has_in_kind, type:*&old_type_meta.type, resource_url:*&old_type_meta.resource_url, rarity:0, power:0, period:0,damping:0,running:0,kind:0, gtype:DICT_TYPE_CATEGORY_GOODS, is_open:false,is_official:false, main_nft_id:nft_id,tags:Vector::empty<u8>(), packages:Vector::empty<PackageV2>() ,extensions:Vector::empty<ExtenstionV2>()};
        let new_nft = NFT::mint_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2, GoodsNFTInfoV2>(owner, &mut new_cap.mint_cap, copy new_base_meta, copy new_type_meta, GoodsNFTBodyV2{quantity:new_amount});
        let new_nft_id = NFT::get_id(&new_nft);

        // burn old nft
        let GoodsNFTBody{ quantity:_ } = NFT::burn_with_cap(&mut new_cap.old_burn_cap,old_nft);

        // deposit new nft to user
        NFTGallery::deposit_to<GoodsNFTInfoV2, GoodsNFTBodyV2>(owner, new_nft);

        let upgrade_nft_event = borrow_global_mut<EventV2<UpgradeNFTEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut upgrade_nft_event.events, UpgradeNFTEventV2{
            goods_id:0,
            main_nft_id:nft_id,
            old_version:1,
            old_nft_id:nft_id,
            new_version:2,
            new_nft_id:new_nft_id,
        });

    }

    // init market
    public fun init_market_v2(sender: &signer, cashier: address, title: vector<u8>, desc: vector<u8>, image: vector<u8>) {       

        check_market_owner_v2(sender);

        let meta = NFT::new_meta_with_image(title, image, desc);
        NFT::register_v2<GoodsNFTInfoV2>(sender, meta);

        // init new capability
        let new_mint_cap = NFT::remove_mint_capability<GoodsNFTInfoV2>(sender);
        let new_burn_cap = NFT::remove_burn_capability<GoodsNFTInfoV2>(sender);
        let new_update_cap = NFT::remove_update_capability<GoodsNFTInfoV2>(sender);
        let old_burn_cap = NFT::remove_burn_capability<GoodsNFTInfo>(sender);
        move_to(sender, GoodsNFTNewCapabilityV2{mint_cap:new_mint_cap, burn_cap:new_burn_cap, update_cap:new_update_cap,old_burn_cap:old_burn_cap});

        // init identity
        move_to<IdentityV2>(sender,IdentityV2{
            id:10000
        });

        // init store house
        move_to<StorehouseV2>(sender,StorehouseV2{
            nfts:Vector::empty<NFT<GoodsNFTInfoV2, GoodsNFTBodyV2>>()
        });

        move_to<EventV2<BuyNowEventV2>>(sender,EventV2<BuyNowEventV2>{
            events:Event::new_event_handle<BuyNowEventV2>(sender),
        });

        // init open box event
        move_to<EventV2<OpenBoxEventV2>>(sender,EventV2<OpenBoxEventV2>{
            events:Event::new_event_handle<OpenBoxEventV2>(sender),
        });

        move_to<EventV2<UpgradeNFTEventV2>>(sender,EventV2<UpgradeNFTEventV2>{
            events:Event::new_event_handle<UpgradeNFTEventV2>(sender),
        });

        // init put on event
        move_to<EventV2<PutOnEventV2>>(sender,EventV2<PutOnEventV2>{
            events:Event::new_event_handle<PutOnEventV2>(sender),
        });
        
        // init pull off event
        move_to<EventV2<PullOffEventV2>>(sender,EventV2<PullOffEventV2>{
            events:Event::new_event_handle<PullOffEventV2>(sender),
        });

        // init bid event
        move_to<EventV2<BidEventV2>>(sender,EventV2<BidEventV2>{
            events:Event::new_event_handle<BidEventV2>(sender),
        });

        // init settlement event
        move_to<EventV2<SettlementEventV2>>(sender,EventV2<SettlementEventV2>{
            events:Event::new_event_handle<SettlementEventV2>(sender),
        });

        // init market
        move_to<MarketV2>(sender, MarketV2{
            counter: 10000,
            is_lock: false,
            funds: Token::zero<STC>(),
            cashier: cashier,
            fee_rate: MARKET_FEE_RATE,
            extensions:Vector::empty<ExtenstionV2>()
        });

        // init partner
        move_to<EventV2<PartnerEventV2>>(sender,EventV2<PartnerEventV2>{
            events:Event::new_event_handle<PartnerEventV2>(sender),
        });

        // init partners
        let partners = Vector::empty<PartnerItemV2>();
        Vector::push_back(&mut partners,PartnerItemV2{
            type:0,
            partner:MARKET_ADDRESS
        });
        move_to<PartnerV2>(sender, PartnerV2{
            members:partners
        });

    }

    // update nft meta
    public fun update_meta_v1(sender: &signer, title: vector<u8>, desc: vector<u8>, image: vector<u8>) acquires GoodsNFTCapability {
        check_market_owner_v2(sender); // check authorize

        let meta = NFT::new_meta_with_image(title, image, desc);// new a meta
        let cap = borrow_global_mut<GoodsNFTCapability>(MARKET_ADDRESS);// borrow cap
        NFT::update_nft_type_info_meta_with_cap<GoodsNFTInfo>(&mut cap.update_cap, meta); // change nft meta info
    }

    // update nft meta
    public fun update_meta_v2(sender: &signer, title: vector<u8>, desc: vector<u8>, image: vector<u8>) acquires GoodsNFTNewCapabilityV2 {
        check_market_owner_v2(sender); // check authorize
        
        let meta = NFT::new_meta_with_image(title, image, desc);// new a meta
        let cap = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);// borrow cap
        NFT::update_nft_type_info_meta_with_cap<GoodsNFTInfoV2>(&mut cap.update_cap, meta); // change nft meta info
    }

    // check partners
    fun check_partner_exist(partner: address): bool acquires PartnerV2 {
        let i = 0u64;
        let result = false;
        let partners = borrow_global_mut<PartnerV2>(MARKET_ADDRESS);
        let len = Vector::length(&partners.members);
        while(i < len){
            let user = Vector::borrow(&partners.members, i);
            if( *&user.partner == partner){
                result = true;
                break
            };
            i = i + 1;
        };
        result
    }

    // create partner
    public fun create_partner_v2(sender: &signer, partner: address, type:u64) acquires PartnerV2,EventV2 {
        check_market_owner_v2(sender);
        
        let owner = Signer::address_of(sender);
        assert!(check_partner_exist(partner)==false,Errors::invalid_argument(1000));

        let partners = borrow_global_mut<PartnerV2>(MARKET_ADDRESS);
        Vector::push_back(&mut partners.members,PartnerItemV2{
            type:type,
            partner:partner
        });

        let partner_event = borrow_global_mut<EventV2<PartnerEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut partner_event.events, PartnerEventV2{
            owner: owner,
            type:type,
            partner: partner,
            method:0,
        });
    }

    // remove partner
    public fun remove_partner_v2(sender: &signer, partner: address) acquires PartnerV2,EventV2 {
        check_market_owner_v2(sender);

        let i = 0u64;
        let owner = Signer::address_of(sender);
        let partners = borrow_global_mut<PartnerV2>(MARKET_ADDRESS);
        let len = Vector::length(&partners.members);
        let type = 0u64;
        while(i < len){
            let user = Vector::borrow(&partners.members, i);
            if( *&user.partner == partner){
                let item = Vector::remove<PartnerItemV2>(&mut partners.members, i);
                type = item.type;
                break
            };
            i = i + 1;
        };

        let partner_event = borrow_global_mut<EventV2<PartnerEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut partner_event.events, PartnerEventV2{
            owner: owner,
            type:type,
            partner: partner,
            method:1,
        });
    }

    // put a new nft on market
    public fun put_on_v2(sender: &signer, title: vector<u8>, sell_way:u64, fixed_price:u128, gtype:u64, tags:vector<u8>, packages:vector<vector<u8>>,package_types:vector<u64>, type: u64, base_price: u128, add_price: u128, image: vector<u8>, resource_url: vector<u8>, desc: vector<u8>, has_in_kind: bool, end_time: u64, amount: u64, original_goods_id: u128,rarity:u64, damping:u64, period:u64, kind:u64) acquires MarketV2,PartnerV2,GoodsBasketV2,EventV2 {
        
        // verify info
        let owner = Signer::address_of(sender);
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        let package_count = Vector::length(&packages);
        let package_type_count = Vector::length(&package_types);
        assert!(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));
        assert!(amount>0 && amount <= ARG_MAX_BID, Errors::invalid_argument(MARKET_INVALID_NFT_AMOUNT));

        // the amount must be equal package_count when boxes
        if(gtype == DICT_TYPE_CATEGORY_BOXES){
            assert!(package_count==package_type_count,Errors::invalid_argument(MARKET_INVALID_PACKAGES));
            assert!(amount == package_count, Errors::invalid_argument(MARKET_INVALID_NFT_AMOUNT));
        }else{
            assert!(package_count==0 && package_type_count==0,Errors::invalid_argument(MARKET_INVALID_PACKAGES));
        };

        if(sell_way==DICT_TYPE_SELL_WAY_BUY_NOW){
            assert!(fixed_price>0 && base_price==0 && add_price==0 && end_time>0,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        }else if(sell_way==DICT_TYPE_SELL_WAY_BID){
            assert!(fixed_price==0 && base_price>0 && add_price>0 && end_time>0,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        }else if(sell_way==DICT_TYPE_SELL_WAY_BUY_NOW_AND_BID){
            assert!(fixed_price>0 && base_price>0 && add_price>0 && end_time>0,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
            assert!(fixed_price>base_price,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        }else{
            assert!(false,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        };

        market_info.counter = market_info.counter + 1;

        let is_official = false;
        if(check_partner_exist(owner)==true && gtype == DICT_TYPE_CATEGORY_BOXES){
            is_official = true;
        }else{
            rarity = 0;
            damping = 0;
            period = 0;
        };

        // create goods
        let new_packages = get_packages_v2(packages,package_types);
        let base_meta = NFT::new_meta_with_image(title, image, desc);
        let type_meta = GoodsNFTInfoV2{has_in_kind, type, resource_url, rarity:rarity, power:0, period:period,damping:damping,running:0,kind:kind, gtype, is_open:false,is_official:is_official, main_nft_id:0,tags, packages:new_packages ,extensions:Vector::empty<ExtenstionV2>()};
        let m2 = copy base_meta;
        let tm2 = copy type_meta;

        // create goods
        let id = (market_info.counter as u128);
        let goods = GoodsV2{
            id: id,
            creator: owner,
            amount: 0,
            nft_id: 0,
            base_price: base_price,
            add_price: add_price,
            last_price: base_price,
            sell_amount: 0,
            end_time: end_time,
            original_goods_id: original_goods_id,
            nft_base_meta: base_meta,
            nft_type_meta: type_meta,
            bid_list: Vector::empty<BidDataV2>(),

            // sell way (0:fixed price, 1:bid, 2:dutch auction)
            sell_way:sell_way,
            // duration time
            duration:0,
            // start time
            start_time: 0,
            // fixed_price
            fixed_price:fixed_price,
            // dutch auction start price
            dutch_start_price:0,
            // dutch auction end price
            dutch_end_price:0,
            // original_amount
            original_amount:amount,
            // extensions
            extensions:Vector::empty<ExtenstionV2>()
        };

        // add basket
        add_basket_v2(sender);
        save_goods_v2(owner, goods);

        // do emit event
        let put_on_event = borrow_global_mut<EventV2<PutOnEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut put_on_event.events, PutOnEventV2 {
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

            // sell way (0:fixed price, 1:bid, 2:dutch auction)
            sell_way:sell_way,
            // duration time
            duration:0,
            // start time
            start_time: 0,
            // fixed_price
            fixed_price:fixed_price,
            // dutch auction start price
            dutch_start_price:0,
            // dutch auction end price
            dutch_end_price:0,
            // original_amount
            original_amount:amount,
            // extensions
            extensions:Vector::empty<ExtenstionV2>()
        });
    }

    // put a exist nft on  market 
    public fun put_on_nft_v2(sender: &signer, nft_id: u64, sell_way:u64, fixed_price:u128, tags:vector<u8>, version:u64, base_price: u128, add_price: u128, end_time: u64, original_goods_id: u128) acquires MarketV2, GoodsNFTNewCapabilityV2, GoodsBasketV2,StorehouseV2,EventV2,GoodsNFTCapability{
        
        // check lock
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        assert!(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        NFTGallery::accept<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender);

        // check sell way
        if(sell_way==DICT_TYPE_SELL_WAY_BUY_NOW){
            assert!(fixed_price>0 && base_price==0 && add_price==0 && end_time>0,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        }else if(sell_way==DICT_TYPE_SELL_WAY_BID){
            assert!(fixed_price==0 && base_price>0 && add_price>0 && end_time>0,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        }else if(sell_way==DICT_TYPE_SELL_WAY_BUY_NOW_AND_BID){
            assert!(fixed_price>0 && base_price>0 && add_price>0 && end_time>0,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
            assert!(fixed_price>base_price,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        }else{
            assert!(false,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        };

        if(version==1){
            put_on_nft_old_v2(sender,nft_id,sell_way,fixed_price,tags,base_price,add_price,end_time,original_goods_id);
        }else if(version==2){
            put_on_nft_new_v2(sender,nft_id,sell_way,fixed_price,tags,base_price,add_price,end_time,original_goods_id);
        }else{
            assert!(false, Errors::invalid_argument(MARKET_INVALID_NFT_ID));
        }

    }

    public fun to_string(num: u64):vector<u8> {
        let buf = Vector::empty<u8>();
        let i = num;
        let remainder:u8;
        loop{
            remainder = ((i % 10) as u8);
            Vector::push_back(&mut buf, 48 + remainder);
            i = i /10;
            if(i == 0){
                break
            };
        };
        Vector::reverse(&mut buf);
        buf
    }

    // open mystery box
    public fun open_box_v2(sender: &signer, nft_id: u64, quantity: u64) acquires EventV2,MarketV2,IdentityV2,GoodsNFTNewCapabilityV2{

        // check lock      
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        assert!(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        // check nft
        let sender_addr = Signer::address_of(sender);
        let new_nft = NFTGallery::withdraw<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender, nft_id);
        assert!(Option::is_some(&new_nft), Errors::invalid_argument(MARKET_INVALID_NFT_ID));

        // check quantity 
        let nft = Option::destroy_some(new_nft);
        let cap = borrow_global_mut<GoodsNFTNewCapabilityV2>(MARKET_ADDRESS);
        let nft_info = NFT::get_info<GoodsNFTInfoV2, GoodsNFTBodyV2>(&nft);
        let (_, _, base_meta, type_meta) = NFT::unpack_info<GoodsNFTInfoV2>(nft_info);
        let count = Vector::length(&type_meta.packages);
        assert!(count>0 && quantity>0 && quantity<=count,Errors::invalid_argument(MARKET_INVALID_NFT_AMOUNT));

        // open boxes
        let now = Timestamp::now_milliseconds();
        let identity = borrow_global_mut<IdentityV2>(MARKET_ADDRESS);
        let i = 0u64;
        while(i < quantity){
            let random = now + i + 100 * i;
            let index = random % (count-i); 
            let item = Vector::remove<PackageV2>(&mut type_meta.packages, index);

            // generate name
            let name = Vector::empty<u8>();
            Vector::append(&mut name,NFT::meta_name(&base_meta));
            Vector::append(&mut name,(b" #"));
            Vector::append(&mut name,to_string(item.id));
            
            // use the box resource to create new nft
            let preview_url = if(item.type == 0){
                *&item.resource
            }else{
                NFT::meta_image(&base_meta)
            };
            let resource_url = *&item.resource;
            identity.id = identity.id +1;

            // power
            let core = now + (i+1) * 10000;
            let power = if(*&type_meta.is_official==true){
                if(*&type_meta.rarity==DICT_TYPE_RARITY_NORMAL){
                    core % (80 - 30 + 1) + 30
                }else if(*&type_meta.rarity==DICT_TYPE_RARITY_EXECLLENT){
                    core % (100 - 50 + 1) + 50
                }else{
                    0
                }
            }else{
                0
            };

            let new_base_meta = NFT::new_meta_with_image(*&name, copy preview_url, NFT::meta_description(&base_meta));
            let new_type_meta = GoodsNFTInfoV2{ has_in_kind:*&type_meta.has_in_kind, type:*&type_meta.type, resource_url:*&item.resource, rarity:*&type_meta.rarity, power:power, period:*&type_meta.period,damping:*&type_meta.damping,running:0,kind:*&type_meta.kind, gtype:DICT_TYPE_CATEGORY_GOODS, is_open:true,is_official:*&type_meta.is_official, main_nft_id:identity.id,tags:*&type_meta.tags, packages:Vector::empty<PackageV2>() ,extensions:Vector::empty<ExtenstionV2>() };
            let new_nft = NFT::mint_with_cap<GoodsNFTInfoV2, GoodsNFTBodyV2, GoodsNFTInfoV2>(MARKET_ADDRESS, &mut cap.mint_cap, copy new_base_meta, copy new_type_meta, GoodsNFTBodyV2{quantity:1});
            let new_nft_id = NFT::get_id(&new_nft);

            // deposit new nft to user
            NFTGallery::deposit_to<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender_addr, new_nft);

            // do emit event
            let open_box_event = borrow_global_mut<EventV2<OpenBoxEventV2>>(MARKET_ADDRESS);
            Event::emit_event(&mut open_box_event.events, OpenBoxEventV2 {
                parent_main_nft_id:*&type_meta.main_nft_id,
                main_nft_id:identity.id,
                new_nft_id:new_nft_id,
                new_version:2,
                preview_url:preview_url,

                rarity: new_type_meta.rarity,
                power:new_type_meta.power,
                period:new_type_meta.period,
                damping:new_type_meta.damping,
                running:new_type_meta.running,
                kind:new_type_meta.kind,
                unopen:count-quantity,
                time:Timestamp::now_seconds(),
                is_open:true,
                is_official:new_type_meta.is_official,
                title:*&name,
                resource_url:resource_url
            });

            i = i+1;
        };

        // burn nft
        if(count==quantity){
            let GoodsNFTBodyV2{ quantity:_ } = NFT::burn_with_cap(&mut cap.burn_cap,nft);
        }else{
            NFT::update_meta_with_cap(&mut cap.update_cap, &mut nft,copy base_meta,copy type_meta);
            NFTGallery::deposit_to<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender_addr, nft);
        };
    }

    // bid goods
    public fun bid_v2(sender: &signer, seller: address, goods_id: u128, price: u128, quantity: u64) acquires EventV2, MarketV2, GoodsBasketV2 {
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        assert!(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        // check owner
        let sender_addr = Signer::address_of(sender);
        assert!(sender_addr!=seller, Errors::invalid_argument(MARKET_INVALID_BUYER));
        
        let basket = borrow_global_mut<GoodsBasketV2>(seller);
        let goods = borrow_goods_v2(&mut basket.items, goods_id);
        if(goods.nft_id > 0) {
            assert!(quantity == goods.original_amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));
        };

        assert!(goods.sell_way==DICT_TYPE_SELL_WAY_BID || goods.sell_way==DICT_TYPE_SELL_WAY_BUY_NOW_AND_BID,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));
        
        let now = Timestamp::now_seconds();
        let remain = goods.original_amount - goods.amount;
        assert!(now < goods.end_time, Errors::invalid_state(MARKET_ITEM_EXPIRED));
        assert!(quantity > 0 && quantity <= remain, Errors::invalid_argument(MARKET_INVALID_QUANTITY));
        let last_price = if(quantity <= remain - goods.sell_amount) {
            goods.base_price
        } else {
            get_bid_price_v2(&goods.bid_list, goods.base_price, quantity)
        };
        assert!(check_price(last_price, goods.add_price, price), Errors::invalid_argument(MARKET_INVALID_PRICE));
        //accept nft
        NFTGallery::accept<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender);
        //save state
        let new_amount = price * (quantity as u128);
        //deduction
        let tokens = Account::withdraw<STC>(sender, new_amount);
        Token::deposit(&mut market_info.funds, tokens);
        save_bid_v2(&mut goods.bid_list, BidDataV2{
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
        if(goods.sell_amount + quantity <= remain) {
            goods.sell_amount = goods.sell_amount + quantity;
        }else{
            goods.sell_amount = remain;
        };
        sort_bid_v2(&mut goods.bid_list);
        let limit = remain;
        refunds_by_bid_v2(&mut goods.bid_list, limit, &mut market_info.funds);

        // do emit event
        let bid_event = borrow_global_mut<EventV2<BidEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut bid_event.events, BidEventV2{
            bidder: sender_addr,
            goods_id: goods_id,
            price: price,
            quantity: quantity,
            bid_time: now,
        });
    }

    // buy now v2
    public fun buy_now_v2(sender: &signer, seller: address, goods_id: u128, quantity: u64) acquires EventV2,MarketV2,IdentityV2,StorehouseV2, GoodsBasketV2,GoodsNFTNewCapabilityV2,StakingPoolV2 {//EventV2, 

        let now = Timestamp::now_seconds();
        let buyer = Signer::address_of(sender);

        // check owner
        assert!(buyer!=seller, Errors::invalid_argument(MARKET_INVALID_BUYER));

        // check lock
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        assert!(market_info.is_lock == false, Errors::invalid_state(MARKET_LOCKED));

        // get goods
        let basket = borrow_global_mut<GoodsBasketV2>(seller);
        let goods = borrow_goods_v2(&mut basket.items, goods_id);

        // check buy all nft if the nft is minted
        if(goods.nft_id > 0) {
            assert!(quantity == goods.original_amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));
        };

        // check sell way
        assert!(goods.sell_way==DICT_TYPE_SELL_WAY_BUY_NOW || goods.sell_way==DICT_TYPE_SELL_WAY_BUY_NOW_AND_BID,Errors::invalid_argument(MARKET_INVALID_SELL_WAY));

        // accept nft
        NFTGallery::accept<GoodsNFTInfoV2, GoodsNFTBodyV2>(sender);

        // transfer tokens to market
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        let fixed_price = goods.fixed_price;
        let token_amount = fixed_price * (quantity as u128);
        let tokens = Account::withdraw<STC>(sender, token_amount);
        Token::deposit(&mut market_info.funds, tokens);

        let is_remove = false;
        if(goods.sell_way==DICT_TYPE_SELL_WAY_BUY_NOW){

            // check quantity
            assert!(quantity > 0 && goods.amount + quantity <= goods.original_amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));

            // update goods amount
            goods.amount = goods.amount + quantity;

            if(goods.amount==goods.original_amount){
                is_remove=true;
            }

        }else if(goods.sell_way==DICT_TYPE_SELL_WAY_BUY_NOW_AND_BID){

            // check quantity
            assert!(quantity > 0 && goods.amount + quantity <= goods.original_amount, Errors::invalid_argument(MARKET_INVALID_QUANTITY));

            // check end time
            assert!(now < goods.end_time, Errors::invalid_state(MARKET_ITEM_EXPIRED));

            // calculate amount
            goods.amount = goods.amount + quantity;

            // calculate remain amount
            let remain = goods.original_amount - goods.amount;
            if(goods.sell_amount > remain){
                goods.sell_amount = remain;
            };

            //assert!(quantity==0,Errors::invalid_argument(SYSTEM_ERROR_TEST));

            // refund bid list
            let limit = goods.original_amount - goods.amount;
            let len = Vector::length(&goods.bid_list);
            if(len>0){
                refunds_by_bid_v2(&mut goods.bid_list, limit, &mut market_info.funds);
            };

            if(limit==0){
                is_remove=true;
                goods.sell_amount=0;
            }
        };


        // buy nft
        let nft_id = goods.nft_id;
        let sell_way = goods.sell_way;
        let lock_amount = goods.sell_amount;
        let settle_amount = goods.amount;
        let original_amount = goods.original_amount;
        let remain_amount = original_amount - goods.amount;
        let bm = *&goods.nft_base_meta;
        let tm = *&goods.nft_type_meta;
        let main_nft_id = tm.main_nft_id;
        let gtype = tm.gtype;
        let is_open = tm.is_open;
        let rarity = tm.rarity;
        let power = tm.power;
        let period = tm.period;
        let damping = tm.damping;
        let running = tm.running;
        let kind = tm.kind;
        let is_official = tm.is_official;

        if(nft_id > 0) {
            // transfer nft to buyer
            let storehouse = borrow_global_mut<StorehouseV2>(MARKET_ADDRESS);
            let op_nft = withdraw_nft_v2(&mut storehouse.nfts, nft_id);
            let nft = Option::destroy_some(op_nft);
            NFTGallery::deposit_to<GoodsNFTInfoV2, GoodsNFTBodyV2>(buyer, nft);

        } else {
            // get ramdom resource if boxes
            if(tm.gtype==DICT_TYPE_CATEGORY_BOXES){
                let packages = get_random_package(&mut goods.nft_type_meta.packages,quantity);
                tm.packages = packages;
            };

            // mint nft to buyer
            let identity = borrow_global_mut<IdentityV2>(MARKET_ADDRESS);
            identity.id = identity.id +1;
            tm.main_nft_id = identity.id;
            main_nft_id = identity.id;
            nft_id = mint_nft_v2(seller, buyer, quantity, bm, tm);
        };

        //handling charge
        let fee = (token_amount * MARKET_FEE_RATE) / 100;
        if(fee > 0u128) {

            // to staking pool
            let pool_info = borrow_global_mut<StakingPoolV2>(MARKET_ADDRESS);
            let staking_fee = (fee * pool_info.fee_rate) / 100;
            if(staking_fee>0u128){
                let staking_tokens = Token::withdraw<STC>(&mut market_info.funds, staking_fee);
                Token::deposit(&mut pool_info.jackpot, staking_tokens);

                // do emit event
                let exchange_nft_event = borrow_global_mut<EventV2<StakingRechargeEventV2>>(MARKET_ADDRESS);
                Event::emit_event(&mut exchange_nft_event.events, StakingRechargeEventV2{
                    owner: buyer,
                    amount: staking_fee,
                    time: Timestamp::now_seconds(),
                    pool_power:pool_info.power,
                    pool_amount:Token::value(&pool_info.jackpot),
                });
            };
            
            // to market fee
            let fee_tokens = Token::withdraw<STC>(&mut market_info.funds, fee - staking_fee);
            Account::deposit(market_info.cashier, fee_tokens);

            // to pay
            let pay_tokens = Token::withdraw<STC>(&mut market_info.funds, token_amount - fee);
            Account::deposit(seller, pay_tokens);

        } else {
            //to pay
            let pay_tokens = Token::withdraw<STC>(&mut market_info.funds, token_amount);
            Account::deposit(seller, pay_tokens);
        };

        // delete goods info
        if(is_remove==true){
            let get_remove_goods = get_goods_v2(seller, goods_id);
            let _ = Option::extract(&mut get_remove_goods);
        };

        // do emit event
        let buy_now_event = borrow_global_mut<EventV2<BuyNowEventV2>>(MARKET_ADDRESS);
        Event::emit_event(&mut buy_now_event.events, BuyNowEventV2 {
            seller: seller,
            buyer:buyer,
            goods_id: goods_id,
            nft_id: nft_id,
            price: fixed_price,
            quantity: quantity,
            time: now,
            main_nft_id:main_nft_id,
            sell_way:sell_way,
            remain_amount:remain_amount,
            gtype:gtype,
            rarity: rarity,
            power:power,
            period:period,
            damping:damping,
            running:running,
            kind:kind,
            is_open:is_open,
            is_official:is_official,
            amount:settle_amount,
            sell_amount:lock_amount,
            original_amount:original_amount
        });

    }

    fun get_random_package(packages:&mut vector<PackageV2>,quantity:u64): vector<PackageV2>{
        let new_packages = Vector::empty<PackageV2>();
        let count = Vector::length(packages);
        let i=0u64;
        let now = Timestamp::now_milliseconds();
        while(i < quantity){
            let random = now + i + 100 * i;
            let index = random % (count - i);
            let package = Vector::remove<PackageV2>(packages, index);
            Vector::push_back<PackageV2>(&mut new_packages,*&package);
            i = i + 1;
        };
        new_packages
    }

    // settlement v2
    public fun settlement_v2(sender: &signer, seller: address, goods_id: u128) acquires EventV2,MarketV2,IdentityV2,StorehouseV2, GoodsBasketV2, GoodsNFTNewCapabilityV2,StakingPoolV2 {
        check_market_owner_v2(sender);

        let owner = Signer::address_of(sender);
        let basket = borrow_global_mut<GoodsBasketV2>(seller);
        let g = borrow_goods_v2(&mut basket.items, goods_id);
        let now = Timestamp::now_seconds();
        assert!(now >= g.end_time, Errors::invalid_state(MARKET_NOT_OVER));
        let len = Vector::length(&g.bid_list);
        if(len > 0) {
            let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
            let storehouse = borrow_global_mut<StorehouseV2>(MARKET_ADDRESS);
            let og = get_goods_v2(seller, goods_id);
            let goods = Option::extract(&mut og);
            let pkg = *&goods.nft_type_meta.packages;
            let i = 0u64;
            while(i < len) {
                let nft_id = goods.nft_id;
                let lock_amount = 0;
                let settle_amount = goods.amount + goods.sell_amount;
                let original_amount = goods.original_amount;
                let bm = *&goods.nft_base_meta;
                let tm = *&goods.nft_type_meta;
                let gtype = tm.gtype;
                let is_open = tm.is_open;
                let main_nft_id = tm.main_nft_id;
                let rarity = tm.rarity;
                let power = tm.power;
                let period = tm.period;
                let damping = tm.damping;
                let running = tm.running;
                let kind = tm.kind;
                let is_official = tm.is_official;
                let bid_data = borrow_bid_data_v2(&mut goods.bid_list, i);
                if(nft_id > 0) {
                    // transfer nft to buyer
                    let op_nft = withdraw_nft_v2(&mut storehouse.nfts, nft_id);
                    let nft = Option::destroy_some(op_nft);
                    NFTGallery::deposit_to<GoodsNFTInfoV2, GoodsNFTBodyV2>(bid_data.buyer, nft);

                } else {
                    // get ramdom resource if boxes
                    if(tm.gtype==DICT_TYPE_CATEGORY_BOXES){
                        let packages = get_random_package(&mut pkg,bid_data.quantity);
                        tm.packages = packages;
                    };

                    // mint nft to buyer
                    let identity = borrow_global_mut<IdentityV2>(MARKET_ADDRESS);
                    identity.id = identity.id +1;
                    tm.main_nft_id = identity.id;
                    main_nft_id = identity.id;
                    nft_id = mint_nft_v2(seller, bid_data.buyer, bid_data.quantity, bm, tm);
                };

                //handling charge
                let fee = (bid_data.total_coin * MARKET_FEE_RATE) / 100;
                if(fee > 0u128) {
                    // to staking pool
                    let pool_info = borrow_global_mut<StakingPoolV2>(MARKET_ADDRESS);
                    let staking_fee = (fee * pool_info.fee_rate) / 100;
                    if(staking_fee>0u128){
                        let staking_tokens = Token::withdraw<STC>(&mut market_info.funds, staking_fee);
                        Token::deposit(&mut pool_info.jackpot, staking_tokens);

                        // do emit event
                        let exchange_nft_event = borrow_global_mut<EventV2<StakingRechargeEventV2>>(MARKET_ADDRESS);
                        Event::emit_event(&mut exchange_nft_event.events, StakingRechargeEventV2{
                            owner: owner,
                            amount: staking_fee,
                            time: Timestamp::now_seconds(),
                            pool_power:pool_info.power,
                            pool_amount:Token::value(&pool_info.jackpot),
                        });
                    };
            
                    // to market fee
                    let fee_tokens = Token::withdraw<STC>(&mut market_info.funds, fee - staking_fee);
                    Account::deposit(market_info.cashier, fee_tokens);

                    //to pay
                    let pay_tokens = Token::withdraw<STC>(&mut market_info.funds, bid_data.total_coin - fee);
                    Account::deposit(seller, pay_tokens);


                } else {
                    //to pay
                    let pay_tokens = Token::withdraw<STC>(&mut market_info.funds, bid_data.total_coin);
                    Account::deposit(seller, pay_tokens);
                };

                // do emit event
                let settlement_event = borrow_global_mut<EventV2<SettlementEventV2>>(MARKET_ADDRESS);
                Event::emit_event(&mut settlement_event.events, SettlementEventV2 {
                    seller: seller,
                    buyer: bid_data.buyer,
                    goods_id: goods_id,
                    nft_id: nft_id,
                    price: bid_data.price,
                    quantity: bid_data.quantity,
                    bid_time: bid_data.bid_time,
                    time: now,
                    main_nft_id:main_nft_id,
                    sell_way:goods.sell_way,
                    gtype:gtype,
                    rarity: rarity,
                    power:power,
                    period:period,
                    damping:damping,
                    running:running,
                    kind:kind,
                    is_open:is_open,
                    is_official:is_official,
                    amount:settle_amount,
                    sell_amount:lock_amount,
                    original_amount:original_amount
                });
                i = i + 1;
            }
        } else {
            market_pull_off_v2(seller, goods_id);
        };
    }

    // lock market
    public fun set_lock_v2(sender: &signer, is_lock: bool) acquires MarketV2 {
        check_market_owner_v2(sender);
        let market_info = borrow_global_mut<MarketV2>(MARKET_ADDRESS);
        market_info.is_lock = is_lock;
    }


    // check owner
    fun check_market_owner_v2(sender: &signer): address {
        let addr = Signer::address_of(sender);
        assert!(addr == MARKET_ADDRESS, Errors::invalid_argument(1000));
        addr
    }



}

module MarketScript {
    use 0x2d32bee4f260694a0b3f1143c64a505a::Market;

    //account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::init_market --arg 0x2d32bee4f260694a0b3f1143c64a505a
    public(script) fun init_market(account: signer, cashier: address) {
        Market::init(&account, cashier);
    }

    //account execute-function -b --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::put_on --arg <...>
    public(script) fun put_on(account: signer, title: vector<u8>, type: u64, base_price: u128, add_price: u128, image: vector<u8>, resource_url: vector<u8>, desc: vector<u8>, has_in_kind: bool, end_time: u64, amount: u64, mail: vector<u8>, original_goods_id: u128) {
        Market::put_on(&account, title, type, base_price, add_price, image, resource_url, desc, has_in_kind, end_time, amount, mail, original_goods_id);
    }

    //account execute-function -b --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::put_on_nft --arg <...>
    public(script) fun put_on_nft(sender: signer, nft_id: u64, base_price: u128, add_price: u128, end_time: u64, mail: vector<u8>, original_goods_id: u128) {
        Market::put_on_nft(&sender, nft_id, base_price, add_price, end_time, mail, original_goods_id);
    }

    //account execute-function -b --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::pull_off --arg <...>
    public(script) fun pull_off(account: signer, goods_id: u128) {
        Market::pull_off(&account, goods_id);
    }

    // account execute-function -b --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::bid --arg 0x2d32bee4f260694a0b3f1143c64a505a 1u128 12u128 1u64
    // "gas_used": "344104"
    public(script) fun bid(account: signer, seller: address, goods_id: u128, price: u128, quantity: u64) {
        Market::bid(&account, seller, goods_id, price, quantity);
    }

    // account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::settlement --arg 0x2d32bee4f260694a0b3f1143c64a505a 1u128
    public(script) fun settlement(sender: signer, seller: address, goods_id: u128) {
        Market::settlement(&sender, seller, goods_id);
    }

    // account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::set_lock --arg false
    public(script) fun set_lock(sender: signer, is_lock: bool) {
        Market::set_lock(&sender, is_lock);
    }

    public(script) fun upgrade(sender: signer) {
        Market::upgrade(&sender);
    }


    // ================================================================================(new version)=========================================================================================================

    //account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::init_market_v2 --arg <...>
    public(script) fun init_market_v2(sender: signer, cashier: address) {
        let title = b"CyberRare";
        let gallary1 = b"https://www.cyberrare.io/v1.png";
        let gallary2 = b"https://www.cyberrare.io/v2.png";
        let description = b"The world's first NFT platform based on Starcoin Public chain, supported by the secure and efficient infrastructure of Starcoin Public chain, provides a market for various forms of digital art and collectibles.";
        Market::update_meta_v1(&sender,copy title, copy description, gallary1);
        Market::init_market_v2(&sender, cashier,  title, description, gallary2);
    }

    //account execute-function -b --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::exchange_nft_v2 --arg <...>
    public(script) fun exchange_nft_v2(sender: signer, nft_id: u64) {
        Market::exchange_nft_v2(&sender, nft_id);
    }

    //account execute-function -b --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::put_on_v2 --arg <...>
    public(script) fun put_on_v2(sender: signer, title: vector<u8>, sell_way:u64, fixed_price:u128, gtype:u64, tags:vector<u8>, packages:vector<vector<u8>>, package_types:vector<u64>, type: u64, base_price: u128, add_price: u128, image: vector<u8>, resource_url: vector<u8>, desc: vector<u8>, has_in_kind: bool, end_time: u64, amount: u64, original_goods_id: u128,rarity:u64, damping:u64, period:u64, kind:u64){
        Market::put_on_v2(&sender, title,sell_way,fixed_price,gtype,tags,packages,package_types, type, base_price, add_price, image, resource_url, desc, has_in_kind, end_time, amount, original_goods_id, rarity, damping, period, kind);
    }

    //account execute-function -b --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::put_on_nft_v2 --arg <...>
    public(script) fun put_on_nft_v2(sender: signer, nft_id: u64,sell_way:u64, fixed_price:u128, tags:vector<u8>,version:u64, base_price: u128, add_price: u128, end_time: u64, original_goods_id: u128) {
        Market::put_on_nft_v2(&sender, nft_id,sell_way,fixed_price,tags,version, base_price, add_price, end_time, original_goods_id);
    }

    //account execute-function -b --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::pull_off_v2 --arg <...>
    public(script) fun pull_off_v2(sender: signer, goods_id: u128) {
        Market::pull_off_v2(&sender, goods_id);
    }

    // account execute-function -b --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::bid_v2 --arg <...>
    public(script) fun bid_v2(sender: signer, seller: address, goods_id: u128, price: u128, quantity: u64) {
        Market::bid_v2(&sender, seller, goods_id, price, quantity);
    }

    // account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::settlement_v2 --arg <...>
    public(script) fun settlement_v2(sender: signer, seller: address, goods_id: u128) {
        Market::settlement_v2(&sender, seller, goods_id);
    }

    // account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::buy_now_v2 --arg <...>
    public(script) fun buy_now_v2(sender: signer, seller: address, goods_id: u128, quantity: u64) {
        Market::buy_now_v2(&sender, seller, goods_id,quantity);
    }

    // account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::open_box_v2 --arg <...>
    public(script) fun open_box_v2(sender: signer,  nft_id: u64, quantity: u64) {
        Market::open_box_v2(&sender, nft_id,quantity);
    }

    // account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::create_partner_v2 --arg <...>
    public(script) fun create_partner_v2(sender: signer, partner: address, type:u64){
         Market::create_partner_v2(&sender, partner, type);
    }

    // account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::remove_partner_v2 --arg <...>
    public(script) fun remove_partner_v2(sender: signer, partner: address){
         Market::remove_partner_v2(&sender, partner);
    }

    // account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::cancel_goods_v1 --arg <...>
    public(script) fun cancel_goods_v1(sender: signer,seller:address, goods_id: u128)  {
        Market::cancel_goods_v1(&sender, seller,goods_id);
    }

    // account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::cancel_goods_v2 --arg <...>
    public(script) fun cancel_goods_v2(sender: signer,seller:address, goods_id: u128)  {
        Market::cancel_goods_v2(&sender, seller,goods_id);
    }
    
    // account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::sync_market_v2 --arg <...>
    public(script) fun sync_market_v2(sender: signer) {
        Market::sync_market_v2(&sender);
    }
    
    // account execute-function -b -s 0x2d32bee4f260694a0b3f1143c64a505a --function 0x2d32bee4f260694a0b3f1143c64a505a::MarketScript::set_lock_v2 --arg <...>
    public(script) fun set_lock_v2(sender: signer, is_lock: bool) {
        Market::set_lock_v2(&sender, is_lock);
    }

    public(script) fun update_meta_v1(sender: signer, title: vector<u8>, desc: vector<u8>, image: vector<u8>){
        Market::update_meta_v1(&sender, title, desc, image);
    }
    
    public(script) fun update_meta_v2(sender: signer, title: vector<u8>, desc: vector<u8>, image: vector<u8>){
        Market::update_meta_v2(&sender, title, desc, image);
    }

    public(script) fun create_test_data_v2(sender: signer) {
        Market::create_test_data_v2(&sender);
    }

    public(script) fun staking_deposit_v2(sender: signer, nft_id: u64){
        Market::staking_deposit_v2(&sender,nft_id);
    }

    public(script) fun staking_withdraw_v2(sender: signer, nft_id: u64){
        Market::staking_withdraw_v2(&sender,nft_id);
    }
    
    public(script) fun staking_reward_v2(sender: signer, amount: u128, nonce:u64, signature:vector<u8>){
        Market::staking_reward_v2(&sender,amount,nonce,signature);
    }
    
    public(script) fun staking_recharge_v2(sender: signer, amount: u128){
        Market::staking_recharge_v2(&sender,amount);
    }
    
    public(script) fun staking_exchange_v2(sender: signer, nft_id: u64){
        Market::staking_exchange_v2(&sender,nft_id);
    }
    
    public(script) fun staking_add_exchange_v2(sender: signer,packages:vector<vector<u8>>){
        Market::staking_add_exchange_v2(&sender,packages);
    }
        
    public(script) fun staking_clean_exchange_v2(sender: signer){
        Market::staking_clean_exchange_v2(&sender);
    }
    
    public(script) fun init_staking_v2(sender: signer){
        Market::init_staking_v2(&sender);
    }
    
}
}