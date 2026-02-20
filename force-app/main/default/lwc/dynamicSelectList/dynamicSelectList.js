import { LightningElement, api, track } from 'lwc';

export default class DynamicSelectList extends LightningElement {
    //フローからの引数
    @api label;
    @api inputOptions = [];
    @api isRequired = false;
    @api isMultiSelect = false;
    @api isRetainState = false;
    @api defaultSingleValue = '';
    @api defaultMultiValues = [];

    //出力値
    @api selectedValue = '';
    @api selectedValues = [];

    /** 
     * 単一選択フラグ返却関数
    */
    get isSingleSelect(){
        return !this.isMultiSelect;
    }

    /**
     * 選択肢のコンポーネント変換関数
     */
    get formattedOptions(){
        if(!this.inputOptions || this.inputOptions.length === 0) return [];
        return this.inputOptions.map(opt => ({ label: opt, value: opt}));
    }

    /**
     * 初期化処理関数
     */
    connectedCallback(){
        if(this.isRetainState){
            if(this.isMultiSelect){
                this.selectedValues = this.defaultMultiValues ? [...this.defaultMultiValues] : []; //複数選択時の初期値セット

            }else{
                this.selectedValue = this.defaultSingleValue ? this.defaultSingleValue : ''; //単一選択時の初期値セット

            }
        }
    }

    /**
     * 値変更イベント
     */
    handleChange(event) {
        if(this.isMultiSelect){
            this.selectedValues = event.detail.value;
        }else{
            this.selectedValue = event.detail.value;
        }
    }

    /**
     * 入力チェック関数
     */
    @api
    validate(){
        //必須チェック
        if(this.isRequired){
            const isValueEmpty = this.isMultiSelect
                ? (!this.selectedValues || this.selectedValues.length === 0)
                : !this.selectedValue;

            if(isValueEmpty){
                return{
                isValid: false,
                errorMessage: 'この項目は必須です。値を入力してください。'
                };
            }
        }

        return{ isValid: true }; //エラーのない場合はisValid=trueを返却
    }
}