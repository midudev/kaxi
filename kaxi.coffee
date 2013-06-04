###
kaxi
Copyright (c) 2013, Miguel Ángel Durán García

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
###
###
# kaxi (another localStorage library) #
kaxi is a tiny library writen in CoffeScript to help developers to use localStorage and all his benefits. The project is developed by miduga (http://miduga.es). You can contact me in migue@miduga.es
###

# Create the kaxi function
kaxi = ( ->
  # Prefix for cache's keys
  PREFIX = 'k_'
  # Sufix for cache's keys on the expiration items in localStorage
  SUFFIX = '-cacheexpiration'
  # expiration date radix (set to Base-36 for most space savings)
  EXPIRY_RADIX = 10
  # time resolution in minutes
  EXPIRY_UNITS = 60 * 1000;
  # ECMAScript max Date (epoch + 1e8 days)
  MAX_DATE = Math.floor( 8.64e15 / EXPIRY_UNITS )
  # bucket to partitionate the cache
  cacheBucket = ''
  # Determines if localStorage is supported by the browser
  supportsStorage = -> window[ 'localStorage' ] isnt null
  # Determines if native JSON serialization is supported by the browser
  supportsJSON = -> window.JSON isnt null
  # Returns the full string for the localStorage expiration item
  expirationKey = ( key ) -> key + SUFFIX
  # Returns the number of minutes for the current time
  currentTime = -> Math.floor( ( new Date().getTime() ) / EXPIRY_UNITS )
  # Wrapper for the getItem method of localStorage
  getItem = ( key ) -> localStorage.getItem( PREFIX + cacheBucket + key )
  # Wrapper for the setItem method of localStorage
  setItem = ( key, value ) ->
    # Fix for iPad issue - sometimes throws QUOTA_EXCEEDED_ERR on setItem
    localStorage.removeItem( PREFIX + cacheBucket + key )
    localStorage.setItem( PREFIX + cacheBucket + key, value )
  # Wrapper for the removeItem method of localStorage
  removeItem = ( key ) ->
    localStorage.removeItem( PREFIX + cacheBucket + key )
  # return the public methods to use kaxi
  return {
    set: ( key, value, time ) ->
    ###
    Stores the value in localStorage. Expires after specified number of minutes.

    Params:
    {
      'key' : String key where store the value,
      'value' : Object or string to set in the localStorage,
      'time' : Number of minutes to store the cache
    }
    ###
      if not supportsStorage() then return

      # If we don't get a string value, try to stringify
      if typeof value isnt 'string'
        if not supportsJSON() then return
        try
          value = JSON.stringify( value )
        catch e
          # Sometimes we can't stringify due to circular refs
          # in complex objects, so we won't bother storing then.
          return

      try
        setItem( key, value )
      catch e
        if e.name is 'QUOTA_EXCEEDED_ERR' or e.name is 'NS_ERROR_DOM_QUOTA_REACHED'
          # If we exceeded the quota, then we will sort
          # by the expire time, and then remove the N oldest
          storedKeys = []
          i = 0

          while i < localStorage.length
            storedKey = localStorage.key(i)

            if storedKey.indexOf( PREFIX + cacheBucket ) is 0 and storedKey.indexOf(SUFFIX ) < 0

              mainKey = storedKey.substr( ( PREFIX + cacheBucket ).length )
              exprKey = expirationKey( mainKey )
              expiration = getItem( exprKey )

              if expiration
                expiration = parseInt( expiration, EXPIRY_RADIX );
              else
                expiration = MAX_DATE # TODO: Store date added for non-expiring items for smarter removal

              storedKeys.push
                key: mainKey
                size: ( getItem( mainKey ) || '' ).length
                expiration: expiration

            i++

          # Sorts the keys with oldest expiration time last
          storedKeys.sort( ( a, b ) -> b.expiration - a.expiration )

          targetSize = ( value || '' ).length

          while storedKeys.length and targetSize > 0
            storedKey = storedKeys.pop()
            removeItem( storedKey.key )
            removeItem( expirationKey( storedKey.key ) )
            targetSize -= storedKey.size
          
          try
            setItem( key, value )
          catch e
            # value may be larger than total quota
            return
        else
          # If it was some other error, just give up.
          return

      # If a time is specified, store expiration info in localStorage
      if time
        setItem( expirationKey( key ), ( currentTime() + time ).toString( EXPIRY_RADIX ) )
      else
        # In case they previously set a time, remove that info from localStorage.
        removeItem( expirationKey( key ) )

    # Retrieves specified value from localStorage, if not expired.
    # @param {string} key
    # @return {string|Object}
    get: ( key ) ->
      if not supportsStorage() then return

      # Return the de-serialized item if not expired
      exprKey = expirationKey( key )
      expr = getItem( exprKey )

      if expr
        expirationTime = parseInt( expr, EXPIRY_RADIX )
        # Check if we should actually kick item out of storage
        if currentTime() >= expirationTime
          removeItem( key )
          removeItem( exprKey )
          return

      # Tries to de-serialize stored value if its an object, and returns the normal value otherwise.
      value = getItem( key )
      if not value or not supportsJSON() then return value

      try 
        # We can't tell if its JSON or a string, so we try to parse
        return JSON.parse( value )
      catch e
        # If we can't parse, it's probably because it isn't an object
        return value

    # Removes a value from localStorage.
    # Equivalent to 'delete' in memcache, but that's a keyword in JS.
    # @param {string} key
    remove: ( key ) ->
      if not supportsStorage() then return
      removeItem( key )
      removeItem( expirationKey( key ) )

    # Returns whether local storage is supported.
    # Currently exposed for testing purposes.
    # @return {boolean}
    supported: ->
      return supportsStorage()

    # Flushes all kaxi items and expiry markers without affecting rest of localStorage
    flush: ->
      if not supportsStorage() then return
      # loop over all the keys in the localStorage
      for key in localStorage
        if key.indexOf( PREFIX + cacheBucket ) is 0 then localStorage.removeItem( key )
    
    # Appends PREFIX so kaxi will partition data in to different buckets.
    # @param {string} bucket
    setBucket: ( bucket ) ->
      cacheBucket = bucket
    
    # Resets the string being appended to PREFIX so kaxi will use the default storage behavior
    resetBucket: ->
      cacheBucket = ''
  }
)()