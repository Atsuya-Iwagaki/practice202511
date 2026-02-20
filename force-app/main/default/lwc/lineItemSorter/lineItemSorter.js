import { LightningElement, api, track } from 'lwc';
import getRecords from '@salesforce/apex/ItemSortController.getRecords';
import updateSortOrder from '@salesforce/apex/ItemSortController.updateSortOrder';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

const DEFAULT_COL_WIDTH = 140;
const MIN_COL_WIDTH = 80;

export default class lineItemSorter extends LightningElement {
    
    //親レコードID
    @api recordId;

    //汎用パラメータ
    @api childObjectApiName; //ソート対象のオブジェクト名
    @api parentFieldApiName; //親レコード参照項目名
    @api sortFieldApiName; //並び替え項目名
    @api fieldsCsv; //画面表示用項目（カンマ区切り）

    @track lineItems = [];
    @track columns = [];
    @track errorMessage;
    @track objectLabel;

    isLoading = false;
    draggedIndex;

    resizeState = null;
    boundMouseMove;
    boundMouseUp;

    connectedCallback() {
        this.boundMouseMove = this.handleMouseMove.bind(this);
        this.boundMouseUp = this.handleMouseUp.bind(this);
        this.loadData();
    }

    disconnectedCallback() {
        window.removeEventListener('mousemove', this.boundMouseMove);
        window.removeEventListener('mouseup', this.boundMouseUp);
    }

    get hasItems(){
        return this.lineItems && this.lineItems.length > 0;
    }

    get cardTitle(){
        return this.objectLabel ? `${this.objectLabel}の並び替え` : 'レコードの並び替え';
    }

    async loadData() {
        this.isLoading = true;
        this.errorMessage = null;

        try {
            //必須パラメターチェック（Apex側と二重で実施）
            if(!this.recordId) throw new Error('親レコードIDの取得に失敗しました。');
            if (!this.childObjectApiName) throw new Error('childObjectApiName が未指定です。');
            if (!this.parentFieldApiName) throw new Error('parentFieldApiName が未指定です。');
            if (!this.sortFieldApiName) throw new Error('sortFieldApiName が未指定です。');
            if (!this.fieldsCsv) throw new Error('fieldsCsv が未指定です。');

            const result = await getRecords({
                childObjectApiName: this.childObjectApiName,
                parentRecordId: this.recordId, 
                parentFieldApiName: this.parentFieldApiName,
                sortFieldApiName: this.sortFieldApiName,
                fieldsCsv: this.fieldsCsv
            });

             //Apexから並び替え対象のオブジェクト表示名取得
            this.objectLabel = result.objectLabel;

            //表示カラムを作成
            this.columns = Object.keys(result.fieldLabels).map(apiName => ({
                fieldApi: apiName,
                label: result.fieldLabels[apiName],
                width: DEFAULT_COL_WIDTH,
            }));

            //表示レコードを作成
            this.lineItems = result.records.map((rec, idx) => ({
                id: rec.Id,
                itemSortNumber: this.resolvedField(rec, this.sortFieldApiName),
                displayOrder: idx + 1,
                cells: this.columns.map(col => ({
                    fieldApi: col.fieldApi,
                    value: this.resolvedField(rec, col.fieldApi),
                })),
            }));
        } catch (e) {
            this.errorMessage = this.normalizeError(e);
        } finally {
            this.isLoading = false;
        }
    }

    /**共通例外ハンドリング**/
    normalizeError(e){
         return e?.body?.message || e?.message || '処理に失敗しました。';
    }

    get columnWidths() {
        return this.columns.map(col => ({
            key: col.fieldApi,
            style: `width:${col.width || DEFAULT_COL_WIDTH}px;`,
        }));
    }

    resolvedField(record, fieldApi) {
        if(!record || !fieldApi) return '';

        //参照先の項目を確認
        if(fieldApi.includes('.')){
            const parts = fieldApi.split('.');
            if(parts.length !== 2) return '';
            const rel = parts[0];
            const fld = parts[1];
            return record?.[rel]?.[fld]?? '';
            
        }
        return record?.[fieldApi]?? '';
    }

    /**ドラッグ＆ドロップ時の動作設定**/
    handleResizeStart(e) {
        e.preventDefault();
        const index = Number(e.currentTarget.dataset.index);
        const currentWidth = this.columns[index]?.width || DEFAULT_COL_WIDTH;

        this.resizeState = {
            index,
            startX: e.clientX,
            startWidth: currentWidth,
        };

        window.addEventListener('mousemove', this.boundMouseMove);
        window.addEventListener('mouseup', this.boundMouseUp);
    }

    handleMouseMove(e) {
        if (!this.resizeState) {
            return;
        }

        const delta = e.clientX - this.resizeState.startX;
        const nextWidth = Math.max(MIN_COL_WIDTH, this.resizeState.startWidth + delta);

        this.columns = this.columns.map((col, idx) =>
            idx === this.resizeState.index
                ? { ...col, width: nextWidth }
                : col
        );
    }

    handleMouseUp() {
        this.resizeState = null;
        window.removeEventListener('mousemove', this.boundMouseMove);
        window.removeEventListener('mouseup', this.boundMouseUp);
    }

    handleDragStart(e) {
        this.draggedIndex = Number(e.currentTarget.dataset.index);
        e.dataTransfer.dropEffect = 'move';
    }

    handleDragOver(e) {
        e.preventDefault();
        e.dataTransfer.dropEffect = 'move';
    }

    handleDrop(e) {
        e.preventDefault();
        const targetIndex = Number(e.currentTarget.dataset.index);
        if (targetIndex === this.draggedIndex || this.draggedIndex == null) {
            return;
        }

        const items = [...this.lineItems];
        const moved = items.splice(this.draggedIndex, 1)[0];
        items.splice(targetIndex, 0, moved);

        this.lineItems = items.map((item, idx) => ({
            ...item,
            displayOrder: idx + 1,
        }));

        this.draggedIndex = null;
    }

    /**並び替え結果の保存処理**/
    async handleSave() {
        this.isLoading = true;

        try{
            const orderedIds = this.lineItems.map(row => row.id);

            await updateSortOrder({
                recIdsInOrder: orderedIds,
                sortFieldApiName: this.sortFieldApiName,
                childObjectApiName: this.childObjectApiName
            });

            this.showToast('成功', '並び順を保存しました。', 'success');
            await this.loadData();

        }catch (e){
            this.showToast('エラー：', this.normalizeError(e), 'error');
        }finally{
            this.isLoading = false;   
        }
    }

    showToast(title, message, variant){
        this.dispatchEvent(new ShowToastEvent({
            title: title,
            message: message,
            variant: variant
        }));
    }
}