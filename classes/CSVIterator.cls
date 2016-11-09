global with sharing class CSVIterator implements Iterator<String>, Iterable<String>
{
   private String m_CSVData;
   private String m_introValue;
   public CSVIterator(String fileData, String introValue)
   {
      m_CSVData = fileData;
      m_introValue = introValue; 
   }
   global Boolean hasNext()
   {
      return m_CSVData.length() > 0 ? true : false;
   }
   global String next()
   {
        Integer index = m_CSVData.indexOf(m_introValue);
        if(index == -1){
            m_introValue = CSVParser.LF;
            index = m_CSVData.indexOf(m_introValue);
            if(index == -1){
                index = m_CSVData.length();
            }
        }
       String row = m_CSVData.subString(0, index);
       if(index == m_CSVData.length()){
           m_CSVData = '';
       }else{
           m_CSVData = m_CSVData.subString(index + m_introValue.length(),m_CSVData.length());
       }
       system.debug('*** row: ' + row);
       system.debug('*** data: ' + m_CSVData);
       return row;
   }
   global Iterator<String> Iterator()
   {
      return this;   
   }
}