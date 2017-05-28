curl  -XPUT http://192.168.56.101:9200/_scripts/painless/ReviewerProfileUpdater  -H 'Content-Type: application/json' -d '
//====================================
//===    Reviewer-centric object =====
//====================================
// This script summarises the reviews
// made by a single marketplace reviewer.
// A profile is determined:
// "newbie" - less than 5 reviews
// "regular" - more than 5 reviews
// "fanboy" - > 5 reviews, all positive, 
//            always for the same vendor
// "hater" - > 5 reviews, all negative, 
//            always for the same vendor
// "unlucky" - > 5 reviews, mainly negative, 
//            across multiple vendors
//====================================

   
  //Copy doc source to local variable with shorter name
	def docSrc = ctx._source;

	if("create".equals(ctx.op)){
		//initialize entity state
		docSrc.vendors = [];
		docSrc.profile = "newbie";
	}    
	
    // Convert seller array into map for ease of manipulation
    def vendorMap =[:];
    for (vendor in docSrc.vendors) {
      vendorMap[vendor.vendorId]=vendor;
    }
    
    // Consolidate latest batch of events
    for (event in params.events) {
      def vendor =vendorMap[event.vendorId];
      if(vendor ==null){
        vendor=[
          "vendorId": event.vendorId,
          "total_rating":event.rating,
          "num_ratings":1
        ];
        vendorMap[vendor.vendorId]=vendor;
      }else{
        vendor.total_rating += event.rating;
        vendor.num_ratings ++;
      }
    }
    // Update the document with summary properties
    docSrc.vendors = vendorMap.values();
    docSrc.numVendors = vendorMap.size();
    //transient variables
    def totalNumRatings = 0;
    def sumRatings=0;
    def numVendors = docSrc.vendors.size(); 
    for (vendor in docSrc.vendors) {
      totalNumRatings += vendor.num_ratings;
      sumRatings += vendor.total_rating;
    }
    docSrc.avgRating = (float)sumRatings / (float)totalNumRatings;


    // reassess the character of the reviewer
    docSrc.profile="newbie";
    if(totalNumRatings > 5){
      docSrc.profile="regular";
      if(docSrc.avgRating > 4.5){
        if(docSrc.numVendors == 1){
          docSrc.profile="fanboy"
        }
      } else {
        if(docSrc.avgRating <= 2){
          if(docSrc.numVendors == 1){
              docSrc.profile="hater";
          } else {
              docSrc.profile="unlucky";
          }
        }
      }
    } 
'