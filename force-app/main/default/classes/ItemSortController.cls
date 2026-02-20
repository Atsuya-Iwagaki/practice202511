/**
 * クラス名：ItemSortController
 * 機能概要：
 * 作成者：FRW岩垣
 * 作成日：2025.11.
 */
public with sharing class ItemSortController {

    /**
     * インスタンス定義
     * 戻り値1：取得したレコードのリスト
     * 戻り値2：項目表示名
     * 戻り値3：オブジェクト表示名
     */
    public class SortResult{
        @AuraEnabled public List<SObject> records;
        @AuraEnabled public Map<String, String> fieldLabels;
        @AuraEnabled public String objectLabel;
    }

    /**
     * メソッド名：getRecords
     * 機能：任意の子オブジェクトを親参照で絞り込み、指定フィールドのみ取得して返却
     *
     * childObjectApiName : 子オブジェクトAPI名 (例: QuoteLineItem)
     * parentRecordId     : 親レコードId
     * parentFieldApiName : 親参照項目API名 (例: QuoteId)
     * sortFieldApiName   : 並び順格納項目API名 (数値) (例: FX_LineNumberForQuote__c)
     * fieldsCsv          : 表示項目CSV (例: Quantity,UnitPrice,Product2.Name)
     *
     */
    @AuraEnabled(cacheable=false)
    public static SortResult getRecords(
        String childObjectApiName,
        Id parentRecordId,
        String parentFieldApiName,
        String sortFieldApiName,
        String fieldsCsv
    ){

        /** 1) 入力チェック **/
        if(String.isBlank(childObjectApiName)){
            String errorMessage = 'childObjectApiNameが未指定です。';
            AurahandledException e = new AurahandledException(errorMessage);
            e.setMessage(errorMessage);
            throw e;
        }
        if(parentRecordId == null){
            String errorMessage = 'parentRecordIdが未指定です。';
            AurahandledException e = new AurahandledException(errorMessage);
            e.setMessage(errorMessage);
            throw e;
        }
        if (String.isBlank(parentFieldApiName)) {
            String errorMessage = 'parentFieldApiName が未指定です。';
            AurahandledException e = new AurahandledException(errorMessage);
            e.setMessage(errorMessage);
            throw e;
        }
        if (String.isBlank(sortFieldApiName)) {
            String errorMessage = 'sortFieldApiName が未指定です。';
            AurahandledException e = new AurahandledException(errorMessage);
            e.setMessage(errorMessage);
            throw e;
        }
        if (String.isBlank(fieldsCsv)) {
            String errorMessage = 'fieldsCsv が未指定です。';
            AurahandledException e = new AurahandledException(errorMessage);
            e.setMessage(errorMessage);
            throw e;
        }

        /** 2) 並び替え対象オブジェクト取得 **/
        Map<String, Schema.SObjectType> globalMap = Schema.getGlobalDescribe();
        if(!globalMap.containsKey(childObjectApiName)){
            String errorMessage = '指定されたオブジェクトが存在しません: ' + childObjectApiName;
            AurahandledException e = new AurahandledException(errorMessage);
            e.setMessage(errorMessage);
            throw e;
        }

        //対象オブジェクトの項目Mapを取得
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(childObjectApiName);
        Schema.DescribeSObjectResult dsr = targetType.getDescribe();
        Map<String, Schema.SObjectField> fieldMap = dsr.fields.getMap();

        //オブジェクト参照権限を確認
        if(!dsr.isAccessible()){
            String errorMessage = '指定されたオブジェクトに参照権限がありません: ' + childObjectApiName;
            AurahandledException e = new AurahandledException(errorMessage);
            e.setMessage(errorMessage);
            throw e;
        }

        /** 3) 親参照項目・ソート項目チェック **/
        if(!fieldMap.containsKey(parentFieldApiName)){
            String errorMessage = '親参照項目が存在しません: ' + parentFieldApiName;
            AurahandledException e = new AurahandledException(errorMessage);
            e.setMessage(errorMessage);
            throw e;
        }

        if(!fieldMap.containsKey(sortFieldApiName)){
            String errorMessage = 'ソート項目が存在しません: ' + sortFieldApiName;
            AurahandledException e = new AurahandledException(errorMessage);
            e.setMessage(errorMessage);
            throw e;
        }

        //項目権限を確認
        if(!fieldMap.get(parentFieldApiName).getDescribe().isAccessible()){
            String errorMessage ='親参照項目に参照権限がありません: ' + parentFieldApiName;
            AurahandledException e = new AurahandledException(errorMessage);
            e.setMessage(errorMessage);
            throw e;
        }

        if(!fieldMap.get(sortFieldApiName).getDescribe().isAccessible()){
            String errorMessage ='ソート項目に参照権限がありません: ' + sortFieldApiName;
            AurahandledException e = new AurahandledException(errorMessage);
            e.setMessage(errorMessage);
            throw e;
        }

        /** 4) ソート項目のデータ型チェック **/
        Schema.DisplayType sortType = fieldMap.get(sortFieldApiName).getDescribe().getType();
        if(sortType != Schema.DisplayType.Double && sortType != Schema.DisplayType.Integer){
            String errorMessage ='ソート項目が数値型ではありません: ' + sortFieldApiName;
            AurahandledException e = new AurahandledException(errorMessage);
            e.setMessage(errorMessage);   
            throw e;       
        }

        /** 5) fieldCsvのチェック（参照項目は2階層まで） **/
        Map<String, String> validFieldMap = parseFields(fieldsCsv, fieldMap);

        /** 6) SELECT句を設定 **/
        Set<String> selectSet = new Set<String>();
        selectSet.add('Id');
        selectSet.add(sortFieldApiName);
        selectSet.addAll(validFieldMap.keySet());

        /** 7) クエリを実行 **/
        List<SObject> recs;

        String soql = 
            'SELECT ' + String.join(new List<String>(selectSet), ',') +
            ' FROM ' + childObjectApiName +
            ' WHERE ' + parentFieldApiName + ' = :parentRecordId' +
            ' ORDER BY ' + sortFieldApiName + ' ASC NULLS LAST';
        
        system.debug('実行クエリ：' + soql);

        try{
            recs = Database.query(soql);
        }catch(Exception e){
            throw new AuraHandledException('レコードが取得できませんでした。：' + e.getMessage());             
        }

        /** 8) 項目表示名を取得 **/      
        SortResult result = new SortResult();
        result.records = recs;
        result.fieldLabels = validFieldMap; // parseFieldsで作ったMapをそのまま格納
        result.objectLabel = dsr.getLabel();
        
        system.debug('結果返却：' + result);
        return result;

    }

   /**
     * 品目にソート番号を設定して更新するメソッド
     * 引数：見積品目のリスト
     * 戻り値：なし
     */
    @AuraEnabled
    public static void updateSortOrder(List<Id> recIdsInOrder, String sortFieldApiName, String childObjectApiName){
  
        system.debug('引数確認：' + recIdsInOrder + ', ' + sortFieldApiName + ', ' + childObjectApiName );
  
        Schema.SObjectType targetType = Schema.getGlobalDescribe().get(childObjectApiName); //オブジェクト名からSObjectTypeを取得
        Integer idx = 1;
        
        List<SObject> updates = new List<SObject>();

        //各レコードにソート番号を付与
        for(Id recid : recIdsInOrder){
            SObject rec = targetType.newSObject(recid);
            rec.put(sortFieldApiName, idx);
            updates.add(rec);
            idx++;
        }
        update updates;

    } 

    /**
     * fieldsCsvを解析し、実在する項目とラベルのMapを返却するメソッド
     * 引数：fieldsCsv, 項目Map
     * 戻り値：Map<項目API名, 項目ラベル>
     */
    private static Map<String, String> parseFields(String fieldsCsv, Map<String, Schema.SObjectField> fieldMap){
        Map<String, String> result = new Map<String, String>(); // 戻り値

        //リレーション名から項目定義を取得するマップを作成
        Map<String, Schema.DescribeFieldResult> relationshipMap = new Map<String, Schema.DescribeFieldResult>();
        for(Schema.SObjectField sof : fieldMap.values()){
            Schema.DescribeFieldResult dfr = sof.getDescribe();
            String rName = dfr.getRelationshipName();
            if(String.isNotBlank(rName)){
                relationshipMap.put(rName.toLowerCase(), dfr);
            }
        }

        //fieldsCsvをカンマ区切りで分割
        List<String> tokens = fieldsCsv.split(',');
        system.debug('トークン：' + tokens);

        for(String token : tokens){

            //各トークンをチェック
            if(String.isBlank(token)) continue;
            String f = token.trim();
            if(String.isBlank(f)) continue;

            if(f.contains('.')){
                // --- 親参照項目の処理 ---
                List<String> parts = f.split('\\.');
                if(parts.size() != 2) continue; 
                
                String relName = parts[0].toLowerCase(); //参照項目名（例：product2）
                String relField = parts[1]; //参照先の項目名（例：Name）

                if(!relationshipMap.containsKey(relName)) continue; // 親項目存在チェック追加

                Schema.DescribeFieldResult parentFieldResult = relationshipMap.get(relName);
                if(parentFieldResult.getReferenceTo().isEmpty()) continue; // 参照先なしチェック

                //参照先オブジェクトの情報を取得
                Schema.SObjectType refType  = parentFieldResult.getReferenceTo()[0];
                Map<String, Schema.SObjectField> refFieldMap = refType.getDescribe().fields.getMap();

                //参照先項目の存在チェック
                if(refFieldMap.containsKey(relField.toLowerCase())){
                    Schema.DescribeFieldResult targetFieldResult = refFieldMap.get(relField.toLowerCase()).getDescribe();
                    // 権限チェック AND ラベル取得
                    if(targetFieldResult.isAccessible()){

                        system.debug('参照先項目を格納：' + f + ', ' + targetFieldResult.getLabel());
                        result.put(f, targetFieldResult.getLabel());
                    }
                }

            } else {
                // --- 通常項目の処理 ---
                if(fieldMap.containsKey(f.toLowerCase())){
                    Schema.DescribeFieldResult targetFieldResult = fieldMap.get(f.toLowerCase()).getDescribe();
                    // 権限チェック AND ラベル取得
                    if(targetFieldResult.isAccessible()){
                        system.debug('項目を格納：' + f + ', ' + targetFieldResult.getLabel());
                        result.put(f, targetFieldResult.getLabel());
                    }
                }
            }
        }
        return result;
    }

}