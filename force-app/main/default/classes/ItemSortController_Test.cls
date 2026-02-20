@IsTest
private class ItemSortController_Test {
    //定数定義
    private static final String CHILD_OBJECT = 'QuoteLineItem';
    private static final String PARENT_FIELD = 'QuoteId';  
    private static final String SORT_FIELD = 'FX_LineNumberForQuote__c';    
    private static final String FIELD_CSV = 'Quantity,UnitPrice,Product2.Name';    
    
    /**
     * テストデータ作成
     * 1.取引先
     * 2.商談
     * 3.見積（明細あり1件、明細なし1件）
     * 4.商品、標準価格表、価格表エントリ
     * 5.見積品目2件
     */
    @TestSetup
    static void setupData(){
        //標準価格表
        Id pricebookId = Test.getStandardPricebookId();

        //商品
        Product2 p = new Product2(
            Name = 'テスト商品',
            ItemID__c = 'MF連携用のApexトリガ起動を回避',
            IsActive = true
        );

        insert p;

        //価格表エントリ
        PricebookEntry pbe = new PricebookEntry(
            Pricebook2Id = pricebookId,
            Product2Id = p.Id,
            UnitPrice = 1000,
            IsActive = true,
            UseStandardPrice = false
        );
        insert pbe;

        //取引先
        Account acc = new Account(Name = 'テスト取引先');
        insert acc;

        //商談
        Opportunity opp = new Opportunity(
            Name      = 'テスト商談',
            StageName = 'Prospecting',
            CloseDate = Date.today().addDays(30),
            AccountId = acc.Id
        );
        insert opp;

        //見積2件
        Quote q1 = new Quote(
        Name = '明細あり見積',
        OpportunityId = opp.Id,
        Pricebook2Id = pricebookId,
        Status = 'Draft'
        );

        Quote q2 = new Quote(
        Name = '明細なし見積',
        OpportunityId = opp.Id,
        Pricebook2Id = pricebookId,
        Status = 'Draft'
        );

        insert new List<Quote>{q1, q2};

        //見積品目（q1に2行追加）
        QuoteLineItem qli1 = new QuoteLineItem(
            QuoteId = q1.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 1,
            UnitPrice = 1000,
            FX_LineNumberForQuote__c = 1
        );

        QuoteLineItem qli2 = new QuoteLineItem(
            QuoteId = q1.Id,
            PricebookEntryId = pbe.Id,
            Quantity = 2,
            UnitPrice = 2000,
            FX_LineNumberForQuote__c = 2
        );

        insert new List<QuoteLineItem>{qli1, qli2};

    }

    /**
     * 正常系：
     * resultが取得できること
     * ソート対象レコードが2件返却されること
     * ソート対象オブジェクトのラベル名が取得できること
     * 参照項目のラベル名が含まれていること
     */
    @IsTest
    static void testGetLineItems_Normal(){
        Quote q = [SELECT Id FROM Quote WHERE Name = '明細あり見積' LIMIT 1];

        Test.startTest();
        ItemSortController.SortResult result = ItemSortController.getRecords(
            CHILD_OBJECT, q.Id, PARENT_FIELD, SORT_FIELD, FIELD_CSV
        );
        Test.stopTest();
        
        Assert.areNotEqual(null, result, '結果が取得できること。');
        Assert.areEqual(2, result.records.size(), '2件取得されること。');
        Assert.areEqual('見積品目名', result.objectLabel, 'オブジェクト表示名が取得できること。');
        Assert.isTrue(result.fieldLabels.containsKey('Product2.Name'), '参照項目のラベルが含まれていること');        

    }

    /**
     * 異常系1：
     * 引数の不備によるバリデーション
     */
    @IsTest
    static void testgetRecords_Validations(){
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        //ソート対象オブジェクト名が未設定
        try{
            ItemSortController.getRecords(null, q.Id, PARENT_FIELD, SORT_FIELD, FIELD_CSV);
        }catch (AuraHandledException e){
            Assert.isTrue(e.getMessage() == 'childObjectApiNameが未指定です。');
        }

        //親レコードIDが未設定
        try{
            ItemSortController.getRecords(CHILD_OBJECT, null, PARENT_FIELD, SORT_FIELD, FIELD_CSV);
        }catch (AuraHandledException e){
            Assert.isTrue(e.getMessage() == 'parentRecordIdが未指定です。');
        }

        //親レコード参照項目が未設定
        try{
            ItemSortController.getRecords(CHILD_OBJECT, q.Id, null, SORT_FIELD, FIELD_CSV);
        }catch (AuraHandledException e){
            Assert.isTrue(e.getMessage() == 'parentFieldApiName が未指定です。');
        }

        //ソート項目が未設定
        try{
            ItemSortController.getRecords(CHILD_OBJECT, q.Id, PARENT_FIELD, null, FIELD_CSV);
        }catch (AuraHandledException e){
            Assert.isTrue(e.getMessage() == 'sortFieldApiName が未指定です。');
        }

        //ソート項目が未設定
        try{
            ItemSortController.getRecords(CHILD_OBJECT, q.Id, PARENT_FIELD, SORT_FIELD, null);
        }catch (AuraHandledException e){
            Assert.isTrue(e.getMessage() == 'fieldsCsv が未指定です。');
        }
    }

    /**
     * 異常系2：
     * 存在しないオブジェクト・項目
     */
    @IsTest
    static void testGetLineItems_InvalidArgument(){
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        //オブジェクト名間違い
        try{
            ItemSortController.getRecords('InvalidObject__x', q.Id, PARENT_FIELD, SORT_FIELD, FIELD_CSV);
        }catch (AuraHandledException e){
            Assert.isTrue(e.getMessage() == '指定されたオブジェクトが存在しません: InvalidObject__x');
        }

        //親レコード参照項目名間違い
        try{
            ItemSortController.getRecords(CHILD_OBJECT, q.Id, 'InvalidField__x', SORT_FIELD, FIELD_CSV);
        }catch (AuraHandledException e){
            Assert.isTrue(e.getMessage() == '親参照項目が存在しません: InvalidField__x');
        }

        //ソート項目名間違い
        try{
            ItemSortController.getRecords(CHILD_OBJECT, q.Id, PARENT_FIELD, 'InvalidField__x', FIELD_CSV);
        }catch (AuraHandledException e){
            Assert.isTrue(e.getMessage() == 'ソート項目が存在しません: InvalidField__x');
        }
    }

    /**
     * 異常系3：
     * ソート項目に数値型以外が指定されている
     */
    @IsTest
    static void testGetLineItems_InvalidSortType(){
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        try{
            ItemSortController.getRecords(CHILD_OBJECT, q.Id, PARENT_FIELD, 'Description', FIELD_CSV);
            Assert.fail('例外が発生するはず');
        }catch(AuraHandledException e){
            Assert.isTrue(e.getMessage() == 'ソート項目が数値型ではありません: Description');
        }
    }

    /**
     * 正常系：
     * parseFieldsの境界値テスト（不正なフィールド名、 クエリ文の不正など）
     */
    @IsTest
    static void testparseFields(){
        Quote q = [SELECT Id FROM Quote LIMIT 1];
        
        //存在しない項目、3階層以上の参照形式、空トークンを混ぜる
        String invalidCsv = 'Quantity,Invalid__x,Product2.Name, Product2.Name.Extra, , ';

        Test.startTest();
        ItemSortController.SortResult result = ItemSortController.getRecords(
            CHILD_OBJECT, q.Id, PARENT_FIELD, SORT_FIELD, invalidCsv
        );
        Test.stopTest();

        //実在し、参照権限のある項目のみ格納されているはず
        Assert.areEqual(2, result.fieldLabels.size()); 
        Assert.isTrue(result.fieldLabels.containsKey('Quantity'));       
        Assert.isTrue(result.fieldLabels.containsKey('Product2.Name'));          
    }

    /**
     * 正常系：
     * ソート順の更新
     */
    @IsTest
    static void testUpdateSortOrder(){
        List<QuoteLineItem> items = [SELECT Id FROM QuoteLineItem ORDER BY FX_LineNumberForQuote__c ASC];
        List<Id> idsInOrder = new List<Id>{items[1].Id, items[0].Id};

        Test.startTest();
        ItemSortController.updateSortOrder(idsInOrder, SORT_FIELD, CHILD_OBJECT);
        Test.stopTest();

        //更新結果の確認
        Map<Id, QuoteLineItem> resultDict = new Map<Id, QuoteLineItem>([
            SELECT Id, FX_LineNumberForQuote__c FROM QuoteLineItem WHERE Id IN :idsInOrder
        ]);

        Assert.areEqual(1, resultDict.get(items[1].Id).FX_LineNumberForQuote__c, 'ソート番号は1');
        Assert.areEqual(2, resultDict.get(items[0].Id).FX_LineNumberForQuote__c, 'ソート番号は2');
    }

    /**
     * 異常系：
     * クエリの失敗ケースを検証
     */
    @IsTest
    static void testGetRecords_QuertError(){
        Quote q = [SELECT Id FROM Quote LIMIT 1];

        try{
            ItemSortController.getRecords(CHILD_OBJECT, q.Id, PARENT_FIELD, SORT_FIELD, 'Id');
        }catch(Exception e){
            Assert.isTrue(e.getMessage().contains('レコードが取得できませんでした。：'));
        }
    }   
}