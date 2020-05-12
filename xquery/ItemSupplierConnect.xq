(: This is a xquery module usable only in Basex, as some of the used functions are not available in IICS :)
declare variable $outputFile as xs:string? external:=  'C:\Users\SGovindu\Documents\XQuery\DB_Output\ProcessItemSupplierConnect.xml';
declare variable $inputFile as xs:string? external:=  './sample-data/sampledata.xml';
declare variable $lastModifiedDate as xs:dateTime? external:=  '2020-05-06T17:18:50';
declare variable $useSampleFile as xs:boolean? external:=  false();

(: function to read data from DB:)
declare function local:read-from-db()
{
   let $class := 'com.microsoft.sqlserver.jdbc.SQLServerDriver'
   let $url := 'jdbc:sqlserver://HBSAWS-DEV-DB01:1433;databaseName=halo_stage;'
   let $user := 'halo_pc'
   let $password := 'Infa_Halo'
   let $db := sql:init($class)
   let $halo_stage := sql:connect($url, $user, $password)
   let $sql_data := sql:execute($halo_stage, 'SELECT * FROM dbo.STG_ItemMaster')
   return 
   $sql_data
};

(:To read from sample file :)
declare function local:read-from-file() 
{
  let $sql_data := doc($inputFile)/data/sql:row
  return
  $sql_data
};

let $sql_data := if ($useSampleFile) then local:read-from-file() else local:read-from-db()

let $outputSerializationParameters := <output:serialization-parameters>
  <output:method value='xml'/>
  <output:omit-xml-declaration value='no'/>
</output:serialization-parameters>

let $DataOutput := 
<items>
   <rowCount>{count($sql_data)}</rowCount>
   (: To see sample data :)
   <sample>
    {$sql_data[1]} 
   </sample> 
   
   <ProcessItemMaster 
        xmlns="http://schema.infor.com/InforOAGIS/2" languageCode="GB" 
        releaseID="9.2" 
        systemEnvironmentCode="Production" versionID="2.12.2" 
        xmlns:ns0="http://schema.infor.com/InforOAGIS/2" 
        xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
        xsi:type="ns0:ProcessItemMasterType">
        <ApplicationArea>
            <Sender>
                <LogicalID>lid://infor.file.cim_dev</LogicalID>
                <ComponentID>Webstar</ComponentID>
                <ConfirmationCode>OnError</ConfirmationCode>
            </Sender>
            <CreationDateTime>{current-dateTime()}</CreationDateTime>
            <BODID>{random:uuid()}</BODID>
        </ApplicationArea>
        
        <DataArea>
            <Process>
                <TenantID>infor</TenantID>
                <AccountingEntityID>210_USA</AccountingEntityID>
                <ActionCriteria>
                    <ActionExpression actionCode="Add"/>
                </ActionCriteria>
            </Process>
            
            { 
            for $row at $rownum in $sql_data
            let $Ext_Item_Number := $row/sql:column[@name='Ext_Item_Number']/text()
            let $Config_Code := $row/sql:column[@name='Config_Code']/text()
            return
            <ItemMaster>
                <ItemMasterHeader>
                    <ItemID>
                       <ID name="ITNE">{$Ext_Item_Number}</ID>
                    </ItemID>
                    <UserArea>
                    
                      <Property listID="">
                                  <NameValue name="SUNO">{$row/sql:column[@name='Supplier']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="SITE">{$row/sql:column[@name='Suppl_Item_No']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="SITD">{$row/sql:column[@name='Suppl_Item_Name']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="SITT">{$row/sql:column[@name='Suppl_Item_Desc']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="PUPR">{$row/sql:column[@name='Purchase_Price']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="LOQT">{$row/sql:column[@name='Min_Order_Qty']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="CXTX">{$row/sql:column[@name='Inspection_Text']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="TEXT1">{$row/sql:column[@name='Text_Block']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="RTYP">{$row/sql:column[@name='Text_Block']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="PRCS">{$row/sql:column[@name='Service_Process']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="SUFI">{$row/sql:column[@name='Service']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="FVDT">{$row/sql:column[@name='From_Date']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="UVDT">{$row/sql:column[@name='To_Date']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="SUPR">{$row/sql:column[@name='Set_Up_Price']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="LEA1">{$row/sql:column[@name='Supply_Lead_Time']/text()}</NameValue>
                               </Property>
                               <Property listID="">
                                  <NameValue name="WHLO">{$row/sql:column[@name='Warehouse']/text()}</NameValue>
                               </Property>
                               </UserArea> 
                    </ItemMasterHeader>
             </ItemMaster>
              }
        </DataArea>
    </ProcessItemMaster>
</items>
return
  (
  file:write($outputFile,
  $DataOutput/*:ProcessItemSupplierConnect,$outputSerializationParameters),$DataOutput)                   