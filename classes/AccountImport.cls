public with sharing class AccountImport 
{
    String tabUrl; 
    
    public AccountImport(ApexPages.StandardSetController controller) {
        init();
    } 
    
    public AccountImport() {
         init();
    }
    
    private void init(){
        PageReference page=System.currentPageReference();
         if(page != null){
            Map<String,String> pageMap=page.getParameters();
            tabUrl = pageMap.get('retURL');
         }
         if(tabUrl == null){
            tabUrl = '/' + Account.sObjectType.getDescribe().getKeyPrefix();
         }
          myString= '';
        status = false;
        getJobs();
    } 
    public String myString {get;set;}
    public Boolean status {get;set;}
    public Id batchId{get;set;}
    public List<AsyncApexJob> jobs{get;set;}
    
    public List<AsyncApexJob> getLatestJobs(){
        return jobs;
    }
    
    public void getJobs(){
        String uid = UserInfo.getUserId();
        jobs = [SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors, MethodName, CompletedDate,
                ExtendedStatus, CreatedById, ApexClass.Name, CreatedDate
                        FROM AsyncApexJob WHERE CreatedById =: uid AND ApexClass.Name = 'AccountImportBatch'
               ORDER BY CreatedDate DESC LIMIT 10];
        for(AsyncApexJob job : jobs){
            if(job.Id == batchId){
                if(job.Status == 'Completed' || job.Status == 'Failed'){
                    ApexPages.Message msg = new ApexPages.Message(ApexPages.severity.INFO,'导入完成，详细信息已发送邮件到您的邮箱！');
                    ApexPages.addMessage(msg);
                    status = true;
                }
                break;
            }
        }
        
    }
    
     public PageReference parseData(){
        parseJSONString();
        return Null;
    }
    
    public PageReference cancle(){
          return new PageReference(tabUrl);
    }
    
    public String getSplitter(String data){
        String[] splitter = new List<String>{'\r\n','\n','\r'};
        Integer index = -1;
        for(Integer i = 0; i < splitter.size(); i++){
            index = data.indexOf(splitter[i]);
            if(index >= 0){
                return splitter[i];
            }
        }
        return null;
    }
    
    public List<String> split(String data, String splitter) {
        Boolean found = false;
        Integer startIndex = 0;
        Integer endIndex = 0;
        Integer length = data.length();
        List<String> result = null;
        Integer index = data.indexOf('客户名');
        if(index >= 0){
            startIndex = data.lastIndexOf(splitter, index);
            if(startIndex == -1){
                startIndex = 0;
            }
            endIndex = data.indexOf(splitter, index);
            if(endIndex == -1){
                endIndex = data.length();
            }
            if(startIndex < endIndex){
                
                if(startIndex != 0){
                    startIndex = startIndex + splitter.length();
                }
                String header = data.substring(startIndex, endIndex);
                
                if(endIndex != data.length()){
                    endIndex = endIndex + splitter.length();
                }
                String body = data.substring(endIndex, data.length());
                
                result = new List<String>{header,body,startIndex+'',endIndex+''};
                return result;
            }
        }
        return null;
    }
    
    public List<String> splits(String data,String splitter){
        List<String> parts = split(data,splitter);
        if(parts == null){
            
            return null;
        }
        String[] result = new List<String>();
        result.add(parts[0]);//header
        result.add('');//body
        String body = parts[1];
        while(true){
            parts = split(body,splitter);
            
            if(parts == null || String.isBlank(parts[1])){
                result[1] += body;
                break;
            }
            
            if(parts[2].isNumeric()){
                result[1] += body.substring(0, Integer.valueOf(parts[2]));
                if(!result[1].endsWith(splitter)){
                    body += splitter;
                }
                body = parts[1];
            }else{
                Integer index = body.indexOf(parts[0]);
                if(index == -1){    
                    result[1] += body.substring(0, index);
                    if(!result[1].endsWith(splitter)){
                        body += splitter;
                    }
                    body = parts[1];
                }else{
                    result[1] += body;
                    break;
                }    
            }
        }
        
        return result;
    }
    
    public Map<String,Integer> mapField(String header){
        Map<String,Integer> fieldMap = new Map<String,Integer>();
        List<String> tags = header.split(',');
        String key;
        for(Integer i = 0; i < tags.size(); i++){
            key = tags.get(i).deleteWhitespace();
            if(key != ''){
                fieldMap.put(key, i);
            }
        }
        return fieldMap;
    }
    
    public void parseJSONString() {
        String splitter = getSplitter(myString);
        Boolean found = false;
        system.debug('splitter: '+splitter);
        List<String> parts = splits(myString,splitter);
        if(parts == null || parts.size() == 0){
            system.debug('split: null parts');
            return;
        }
        String header = parts[0];
        String body = parts[1];
        Map<String,Integer> fieldMap;
        System.debug('header:'+header);
        if(!String.isBlank(header)){
            fieldMap = mapField(header);
            if(fieldMap.size() > 0){
                found = true;
            }
        }
        if(!found){
            fieldMap = new Map<String,Integer>();
            fieldMap.put('客户名', 0);
            fieldMap.put('电话', 1);
        }
        
        batchId = AccountImportBatch.run(body,UserInfo.getUserId(),fieldMap);
        getJobs();
        status = false;
    } 
}