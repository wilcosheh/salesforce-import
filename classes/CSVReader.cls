/**
 * CSVReader contains static methods used for reading a CSV file and returning
 * the contained values in a nested List of Strings.
 *
 * @author  Marty Y. Chang
 * @version beta
 */
public class CSVReader {

    public static List<List<String>> readCSVFile(Blob file) {
        String fileString = file.toString();
        return readIETFRFC4180CSVFile(fileString);
    }

    /**
     * Returns a List containing Lists of Strings that represents
     * the values contained in an IETF RFC 4180-compliant CSV file.
     *
     * Each element in the outer list represents a row in the CSV file.
     * Each element in the inner list is the value in the field specified
     * by the row-column combination.
     *
     * @param  file the CSV file to read
     * @return      the List<List<String>> containing values read from the
     *              CSV file
     */
    public static List<List<String>> readIETFRFC4180CSVFile(String fileString) {
        fileString = fileString.replaceAll('\\s*\\z', '');
        
        if (!fileString.endsWith(CSVParser.CRLF)) {
          fileString = fileString + CSVParser.CRLF;
        }
        
        List<List<String>> fileValues = new List<List<String>>();
        List<String> rowValues = new List<String>();
        CSVValue csvValue = new CSVValue();
        
        Boolean eod = false;  // Whether end of CSV data is reached
        while (!eod) {
          System.debug(fileString);
          
            csvValue = readIETFRFC4180CSVValue(fileString);
            
            rowValues.add(csvValue.value);
            
            if (csvValue.delimiter == CSVParser.CRLF) {
              fileValues.add(rowValues);
              
              System.debug(rowValues);
              
              if (fileValues.size() > 0) {
                System.assertEquals(fileValues.get(0).size(),
                      rowValues.size());
              }
              
              rowValues = new List<String>();
            }
            
            if (csvValue.biteSize() == fileString.length()) {
              eod = true;
            }
            else {
              fileString = fileString.substring(csvValue.biteSize());
            }
        }
        
        return fileValues;
    }
    
    /**
     * Returns the first String value read from a String representation of
     * data contained in an IETF RFC 4180-compliant CSV file.
     *
     * The data is assumed to be terminated with a CRLF.
     *
     * @param  data the textual CSV data in one long string
     * @return      the first CSV value read from <code>data</code>.
     *              null is returned if no value is discerned.
     */
    public static CSVValue readIETFRFC4180CSVValue(String data) {
        System.assert(data.endsWith(CSVParser.CRLF));
        
        CSVValue csvValue = new CSVValue();
        
        if (data.startsWith(CSVParser.DQUOTE)) {
          csvValue.enclosed = true;
          
            Integer searchIndex = 1;      // starting index to search
            Integer dquoteIndex = -1;     // index of DQUOTE
            Integer dquotesIndex = -1;    // index of DQUOTEDQUOTE
                            
            Boolean closerFound = false;
            
            while (!closerFound) {
                dquoteIndex = data.indexOf(CSVParser.DQUOTE, searchIndex);
                
                dquotesIndex = data.indexOf(CSVParser.DQUOTEDQUOTE,
                        searchIndex);
                
                System.assert(dquoteIndex != -1);
                
                if (dquoteIndex == dquotesIndex) {
                    searchIndex = dquotesIndex
                            + CSVParser.DQUOTEDQUOTE.length();
                }
                else {
                    closerFound = true;
                }
            }
            
            csvValue.value = data.substring(
                    CSVParser.DQUOTE.length(), dquoteIndex)
                            .replaceAll(CSVParser.DQUOTEDQUOTE, CSVParser.DQUOTE);
            
            Integer commaIndex = data.indexOf(CSVParser.COMMA, dquoteIndex);
            Integer crlfIndex = data.indexOf(CSVParser.CRLF, dquoteIndex);
            
            if (commaIndex != -1 && commaIndex < crlfIndex) {
                csvValue.delimiter = CSVParser.COMMA;
            }
            else {
                csvValue.delimiter = CSVParser.CRLF;
            }
        }
        else {
          csvValue.enclosed = false;
          
            Integer commaIndex = data.indexOf(CSVParser.COMMA);
            Integer crlfIndex = data.indexOf(CSVParser.CRLF);
            
            if (commaIndex != -1 && commaIndex < crlfIndex) {
                csvValue.value = data.substring(0, commaIndex);
                csvValue.delimiter = CSVParser.COMMA;
            }
            else {
                csvValue.value = data.substring(0, crlfIndex);
                csvValue.delimiter = CSVParser.CRLF;
            }
        }
        
        System.debug('Returning: ' + csvValue);
        
        return csvValue;
    }
    
    /**
     * CSVValue is a class structure containing information about a CSV
     * value that was read from a CSV file, including such information as
     * whether the value was encapsulated in double-quotes.
     */
    private class CSVValue {
        /**
         * The field value that was read from the CSV file.
         */
        public String value;
        
        /**
         * Whether the value was surrounded by double-quotes.
         */
        public Boolean enclosed;
        
        /**
         * The comma or CRLF delimiter that identified the end of the CSV value.
         */
        public String delimiter;
        
        /**
         * Default constructor, setting all members to null.
         */
        public CSVValue() {
            this(null, null, null);
        }
        
        /**
         * Constructor.
         *
         * @param value     the field value
         * @param enclosed  whether the value was surrounded by double-quotes
         * @param delimiter the delimiter that identified the end
         *                  of the CSV value
         */
        public CSVValue(String value, Boolean enclosed, String delimiter) {
            this.value = value;
            this.enclosed = enclosed;
            this.delimiter = delimiter;
        }
        
        /**
         * Returns the number of characters to remove from the data
         * String which produced the CSVValue in order to reach the next
         * value in the data String.
         */
        public Integer biteSize() {
          Integer biteSize = value
                 .replaceAll(CSVParser.DQUOTE, CSVParser.DQUOTEDQUOTE).length()
                         + delimiter.length();
          
          if (enclosed) {
            biteSize += CSVParser.DQUOTE.length() * 2;
          }
          
          System.debug('biteSize: ' + biteSize);
          
          return biteSize;
        }
        
        /**
         * Returns whether a CSVValue has the same <code>value</code> and
         * <code>enclosed</code> as another CSVValue.
         */
        public Boolean equals(CSVValue compCSVValue) {
            return this.value.equals(compCSVValue.value)
                    && this.enclosed == compCSVValue.enclosed
                            && this.delimiter == compCSVValue.delimiter;
        }
        
        /**
         * Asserts that two <code>CSVValue</code> instances have the same
         * <code>value</code> and <code>enclosed</code>.
         */
        public void assertEquals(CSVValue compCSVValue) {
            System.assertEquals(value, compCSVValue.value);
            System.assertEquals(enclosed, compCSVValue.enclosed);
            System.assertEquals(delimiter, compCSVValue.delimiter);
        }
    }
    
    /**
     * Test some use cases for reading IETF RFC 4180-compliant CSV values.
     */
  /*  public static testMethod void readIETFRFC4180CSVValueTest() {
        String data = null;  // Placeholder for data to use in testing.
        
        System.debug(data = CSVParser.CRLF);
        new CSVValue('', false, CSVParser.CRLF)
                .assertEquals(readIETFRFC4180CSVValue(data));
        
        System.debug(data = '""' + CSVParser.CRLF);
        new CSVValue('', true, CSVParser.CRLF)
                .assertEquals(readIETFRFC4180CSVValue(data));
        
        System.debug(data = '"",asdf' + CSVParser.CRLF);
        new CSVValue('', true, CSVParser.COMMA)
                .assertEquals(readIETFRFC4180CSVValue(data));
        
        System.debug(data = ',asdf' + CSVParser.CRLF);
        new CSVValue('', false, CSVParser.COMMA)
                .assertEquals(readIETFRFC4180CSVValue(data));
        
        System.debug(data = '"' + CSVParser.CRLF + '",blah' + CSVParser.CRLF);
        new CSVValue(CSVParser.CRLF, true, CSVParser.COMMA)
                .assertEquals(readIETFRFC4180CSVValue(data));
        
        System.debug(data = '"""marty""","""chang"""' + CSVParser.CRLF);
        new CSVValue('"marty"', true, CSVParser.COMMA)
                .assertEquals(readIETFRFC4180CSVValue(data));
        
        System.debug(data = '"com""pli""cate' + CSVParser.CRLF + 'd"'
                + CSVParser.CRLF);
        new CSVValue('com"pli"cate' + CSVParser.CRLF + 'd', true, CSVParser.CRLF)
                .assertEquals(readIETFRFC4180CSVValue(data));
        
        System.debug(data = 'asdf' + CSVParser.CRLF);
        new CSVValue('asdf', false, CSVParser.CRLF)
                .assertEquals(readIETFRFC4180CSVValue(data));
    }*/
    
    /**
     * Tests one case of parsing a CSV file that contains the following data:
     *
     * abc,"def","g""h""i"
     * "j
     * kl","m
     * n""o""",
     */
  /*  public static testMethod void readIETFRFC4180CSVFile() {
      String data = 'abc,"def","g""h""i"' + CSVParser.CRLF + '"j' + CSVParser.CRLF
             + 'kl","m' + CSVParser.CRLF + 'n""o""",';
      
      List<List<String>> fileValues =
             readIETFRFC4180CSVFile(Blob.valueOf(data));
    }*/
}