/**
 * コンポーネント名：screenScrollTop
 * 機能概要：画面フローに設置し、対象画面に遷移した際に自動で画面最上部にスクロールさせる。
 * 作成者：FRW岩垣
 * 作成日：2025.11.24
 */
import { LightningElement, api } from 'lwc';

/** Flowのエラーメッセージ/エラー項目に付くクラスを定義 */ 
const ERROR_SELECTORS = [
    
    '.slds-form-element.slds-has-error', // 項目のエラー（赤枠のコンテナ）
    '.slds-form-element__help' // 項目のエラーメッセージ
].join(', ');

export default class screenScrollTop extends LightningElement {
    @api isInvalid = false;
    _timer;

    renderedCallback() {

        //isInvalid = Trueの場合、後続処理を実行しない
        if(this.isInvalid){
            return;
        }

        //毎回呼ばれるので、タイマーで1回にまとめる
        if (this._timer) {
            window.clearTimeout(this._timer);
        }
        this._timer = window.setTimeout(() => {
            this.handleScroll();
        }, 0);
    }

    handleScroll() {

        if(this.isInvalid){
            return;
        }

        // Flow全体が入っているルートを取得
        const root = this.template.host.getRootNode(); // Document or ShadowRoot
        const errorElement = root.querySelector(ERROR_SELECTORS);

        if (errorElement) {
            // エラーがある場合、最初のエラー付近にスクロール
            errorElement.scrollIntoView({
                behavior: 'smooth',
                block: 'center'
            });
        } else {
            // エラーなしの場合、最上部へスクロール
            window.scrollTo({
                top: 0,
                behavior: 'smooth'
            });
        }
    }

    disconnectedCallback() {

        //コンポーネント破棄時にタイマーをクリア
        if (this._timer) {
            window.clearTimeout(this._timer);
            this._timer = undefined;
        }
    }
}