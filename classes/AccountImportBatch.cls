global with sharing class AccountImportBatch implements Database.batchable<String>, Database.Stateful{
    private String m_csvFile;
    private CSVParser m_parser;
    private String operatorId;
    private Integer total = 0;
    private Integer success = 0;
    private Map<String,Integer> fieldMap;
    private String errorMessages = '';
    private String errorLines = '';
    private static final Integer SCOPE_SIZE = 100;
    public AccountImportBatch(String file, String operatorId,Map<String,Integer> fieldMap){
        this.m_csvFile = file;
        this.operatorId = operatorId;
        this.fieldMap = fieldMap;
    }
    public static Id run(String body, String operatorId, Map<String,Integer> fieldMap){
        AccountImportBatch bat =new AccountImportBatch(body, operatorId, fieldMap);
        return Database.executeBatch(bat, SCOPE_SIZE);
    }
    global Iterable<String> start(Database.batchableContext batchableContext){
        return new CSVIterator(m_csvFile, CSVParser.crlf);
    }
    global void execute(Database.BatchableContext batchableContext, List<String> scope)  {
        String csvFile = '';
        for(String row : scope){
            if(row.replaceAll('\\s*,*\\s*\\z', '').trim()==''){
                continue;
            }
            csvFile += row + CSVParser.crlf;
        }
        List<List<String>> csvLines = CSVReader.readIETFRFC4180CSVFile(csvFile);
        List<Account> records = new List<Account>();
        Integer nameIndex = fieldMap.get('客户名');
        Integer phoneIndex = fieldMap.get('电话');
        Integer size = fieldMap.size();
        List<String> curLine;
        
        for(List<String> csvLine : csvLines){
            if(csvLine.size() < size){
                continue;
            }
            curLine = csvLine;
            total++;
            Account acc = new Account();
            size = csvLine.size();
            try{
                if(nameIndex < size){
                    acc.Name = csvLine.get(nameIndex).trim();
                }
                if(phoneIndex < size){
                    acc.Phone = csvLine.get(phoneIndex).trim();
                }
                records.add(acc);
            }catch(Exception e){
                system.debug('*** e ' + e);
                errorMessages = errorMessages + ' exception occured: ' + e.getMessage() + '.\n';
                if(curLine!=null){
                    for(String str : curLine){
                        errorLines = errorLines + str + ',';
                    }
                    errorLines = errorLines + '\n';
                }
            }
        }
        dealWithRecords(records);
    }
    
    private void dealWithRecords(List<Account> records){
        try{
            if(records.size() > 0){
            
                //insert records;
                Database.SaveResult[] srList = Database.insert(records, false);
                // Iterate through each returned result
                for (Database.SaveResult sr : srList) {
                    if (sr.isSuccess()) {
                        success++;
                    }else{
                        // Operation failed, so get all errors              
                        for(Database.Error err : sr.getErrors()) {
                            errorMessages = errorMessages + ' field ' + err.getFields() + ' affected error: ' + err.getStatusCode() + ':' +err.getMessage() + '.\n';
                        }
                    }
                }
            }
        }catch (Exception e){
            errorMessages = errorMessages + ' exception occured: ' + e.getMessage() + '.\n';
        }   
    }
    
    global void finish(Database.BatchableContext batchableContext){
        String jobResult = '';
        String body = '';
        Id batchId = batchableContext.getJobId();
        AsyncApexJob job;
        if(batchId != null){
            job = [SELECT Id, Status, JobItemsProcessed, TotalJobItems, NumberOfErrors, CompletedDate,
                ExtendedStatus FROM AsyncApexJob WHERE Id =: batchId];
            if(job.Status != 'Completed' || job.TotalJobItems == job.NumberOfErrors){
                jobResult = '导入失败：' + job.ExtendedStatus + '.\n 总批量：' + job.TotalJobItems + ', 已处理：' + job.JobItemsProcessed + ', 失败：' + job.NumberOfErrors + '.\n';
            }
        }

        //给操作员发送完成邮件
        if(String.isNotEmpty(operatorId)){
            User user = [Select Id, LastName, Email From User Where Id =: operatorId];
            if(user != null){
                Messaging.SingleEmailMessage mail=new Messaging.SingleEmailMessage(); 
                String[] adress =new String[]{user.Email};
                mail.setToAddresses(adress);
                mail.setSubject('客户导入');
                body = user.LastName + '您好\n';
                if(String.isBlank(jobResult)){
                    body = body +'您所提交的客户导入任务完成，总处理记录数'+ total +
                    '，成功导入'+ success + '条。';
                    if(!String.isBlank(errorMessages)){
                        body += '错误信息：\n' + errorMessages;
                    }
                    if(job.NumberOfErrors > 0){
                        body += '\n总批量：' + job.TotalJobItems + ', 已处理：' + job.JobItemsProcessed + ', 失败：' + job.NumberOfErrors + '——' + job.ExtendedStatus + '.\n';
                    }
                    if(!String.isBlank(errorLines)){
                        body += '\n错误记录：\n' + errorLines;
                    }
                    
                }else{
                    body += '您所提交的客户导入任务'+ jobResult;
                }
                mail.setHtmlBody(body);
                Messaging.sendEmail(new Messaging.SingleEmailMessage[]{ mail });
            }
        }
    }
    
    
}